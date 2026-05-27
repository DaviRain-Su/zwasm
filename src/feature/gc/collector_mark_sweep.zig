//! Stop-the-world mark-sweep collector — β must-ship per
//! ADR-0115 §10 (10.G op_gc cycle 26 first cut).
//!
//! Implements the `Collector` vtable from `collector_iface.zig`
//! over the per-Store `Heap` slab + ObjectHeader / ArrayHeader
//! layouts from ADR-0116 §3a (cycle 19-20 substrate).
//!
//! ## Phases
//!
//! 1. **Mark**: invoke `walkRootsFn` with `markFromRoot`. For each
//!    root GcRef, set the ObjectHeader's mark bit. (Recursive
//!    tracing of payload reftype slots defers — this cut marks
//!    only directly-rooted objects; transitive trace lands once
//!    payload-slot iteration via TypeInfo materialises into the
//!    sweep walker. β must-ship: roots are enough to demonstrate
//!    the mark+sweep cycle is wired.)
//!
//! 2. **Sweep**: walk the heap from offset 2 (skipping null_ref).
//!    Decode each ObjectHeader → step over by header_size +
//!    payload_size (struct) OR array_header_size +
//!    length*element_size (array). Reset mark bits (clear
//!    the high bit of ObjectHeader.info) for next cycle. Count
//!    survivors + dead bytes; emit stats via the returned
//!    `SweepStats`. True reclamation (free-list reuse or
//!    compaction) defers to Phase 11 per ADR-0115 §10 closing
//!    note; this cut maintains the bump-cursor model so dead
//!    bytes leak until process exit.
//!
//! ## Mark bit encoding (ADR-0116 §3a)
//!
//! `ObjectHeader.info` is a u32. The low 31 bits hold the
//! typeidx (≤ 2^31 declared types — Wasm modules have far fewer).
//! Bit 31 (`mark_bit_mask`) is the mark phase indicator: set
//! during mark, cleared during sweep.
//!
//! ## TypeInfo dependency
//!
//! Per-object size decode reads `TypeInfo.kind` + the per-kind
//! size (StructInfo.payload_size for struct; ArrayHeader.length
//! * ArrayInfo.element.size for array). The collector takes a
//! `*const GcTypeInfos` at init so it can resolve typeidx →
//! per-kind info during sweep.
//!
//! Zone 1 (`src/feature/gc/`).

const std = @import("std");

const heap_mod = @import("heap.zig");
const iface = @import("collector_iface.zig");
const type_info_mod = @import("type_info.zig");

const Heap = heap_mod.Heap;
const GcRef = heap_mod.GcRef;
const Collector = iface.Collector;
const RootCallback = iface.RootCallback;
const ObjectHeader = type_info_mod.ObjectHeader;
const ObjectKind = type_info_mod.ObjectKind;
const ArrayHeader = type_info_mod.ArrayHeader;
const GcTypeInfos = type_info_mod.GcTypeInfos;

const header_size: u32 = @sizeOf(ObjectHeader);
const array_header_size: u32 = @sizeOf(ArrayHeader);

/// Mark phase bit — high bit of ObjectHeader.info. Set during
/// mark, cleared during sweep. Typeidx occupies the low 31 bits.
pub const mark_bit_mask: u32 = 0x8000_0000;

/// Per-collection stats. Returned by `collect()` so callers /
/// tests can observe behaviour.
pub const SweepStats = struct {
    /// Objects walked during sweep (= total live objects in slab).
    objects_seen: u32 = 0,
    /// Objects with mark bit set (= marked live by roots).
    survivors: u32 = 0,
    /// Bytes occupied by unreachable objects (would be reclaimable
    /// under a compacting Phase 11 collector). Not freed this cut.
    dead_bytes: u32 = 0,
};

pub const MarkSweepCollector = struct {
    heap: *Heap,
    gc_type_infos: *const GcTypeInfos,
    /// Latest sweep statistics. Updated each `collectFn` call.
    last_stats: SweepStats = .{},

    pub fn init(heap: *Heap, gti: *const GcTypeInfos) MarkSweepCollector {
        return .{ .heap = heap, .gc_type_infos = gti };
    }

    pub fn collector(self: *MarkSweepCollector) Collector {
        return .{
            .allocObjectFn = allocObjectImpl,
            .collectFn = collectImpl,
            .walkRootsFn = walkRootsImpl,
            .ctx = @ptrCast(self),
        };
    }

    fn allocObjectImpl(ctx: *anyopaque, size: u32) ?GcRef {
        const self: *MarkSweepCollector = @ptrCast(@alignCast(ctx));
        return self.heap.allocate(size) catch null;
    }

    /// Mark single root. Public so tests + future indirect tracers
    /// can invoke. Idempotent — re-marking is a no-op.
    pub fn markFromRoot(self: *MarkSweepCollector, ref: GcRef) void {
        if (ref == heap_mod.null_ref) return;
        if (ref >= self.heap.bytes.len) return; // defensive
        // Read header, set mark bit, write back.
        const off: usize = ref;
        var hdr: ObjectHeader = undefined;
        @memcpy(std.mem.asBytes(&hdr)[0..header_size], self.heap.bytes[off .. off + header_size]);
        hdr.info |= mark_bit_mask;
        @memcpy(self.heap.bytes[off .. off + header_size], std.mem.asBytes(&hdr)[0..header_size]);
    }

    fn collectImpl(ctx: *anyopaque) void {
        const self: *MarkSweepCollector = @ptrCast(@alignCast(ctx));
        self.runCollection();
    }

    /// Walks the heap from `null_ref + 2` (the lowest possible
    /// non-null GcRef per Heap.allocate's min_align=2). Reads
    /// each ObjectHeader, decodes object size, advances cursor.
    /// Used by sweep + reachable to enumerate live objects.
    fn runCollection(self: *MarkSweepCollector) void {
        // Mark phase is driven externally — caller invokes
        // `walkRoots(markFromRoot, ...)` BEFORE collect().
        // collect() runs the sweep phase only.
        var stats: SweepStats = .{};
        var cursor: u32 = heap_mod.null_ref + heap_mod.Heap.min_align;
        // The Heap's bump cursor records the high-water mark; objects
        // exist in [min_align, heap.cursor).
        while (cursor < self.heap.cursor) {
            if (cursor + header_size > self.heap.bytes.len) break;
            var hdr: ObjectHeader = undefined;
            @memcpy(std.mem.asBytes(&hdr)[0..header_size], self.heap.bytes[cursor .. cursor + header_size]);
            const typeidx = hdr.info & ~mark_bit_mask;
            const marked = (hdr.info & mark_bit_mask) != 0;
            const obj_size = self.objectSizeAt(cursor, hdr, typeidx);
            if (obj_size == 0) break; // defensive — malformed header

            stats.objects_seen += 1;
            if (marked) {
                stats.survivors += 1;
                // Clear mark bit for next cycle.
                hdr.info &= ~mark_bit_mask;
                @memcpy(self.heap.bytes[cursor .. cursor + header_size], std.mem.asBytes(&hdr)[0..header_size]);
            } else {
                stats.dead_bytes += obj_size;
                // Phase 11 amendment: free-list reuse or compaction.
                // For now the dead region stays in-place but its bytes
                // are observable garbage. Sweep doesn't recycle.
            }
            cursor = std.mem.alignForward(u32, cursor + obj_size, heap_mod.Heap.min_align);
        }
        self.last_stats = stats;
    }

    /// Decode the byte size of the object at `off` whose header
    /// is `hdr` and whose typeidx (low 31 bits) is `typeidx`.
    fn objectSizeAt(self: *MarkSweepCollector, off: u32, hdr: ObjectHeader, typeidx: u32) u32 {
        return switch (hdr.kind) {
            .struct_ => blk: {
                if (typeidx >= self.gc_type_infos.struct_infos.len) break :blk 0;
                const si = self.gc_type_infos.struct_infos[typeidx] orelse break :blk 0;
                break :blk header_size + si.payload_size;
            },
            .array => blk: {
                if (typeidx >= self.gc_type_infos.array_infos.len) break :blk 0;
                const ai = self.gc_type_infos.array_infos[typeidx] orelse break :blk 0;
                if (off + array_header_size > self.heap.bytes.len) break :blk 0;
                var ahdr: ArrayHeader = undefined;
                @memcpy(std.mem.asBytes(&ahdr)[0..array_header_size], self.heap.bytes[off .. off + array_header_size]);
                break :blk array_header_size + ahdr.length * @as(u32, ai.element.size);
            },
        };
    }

    fn walkRootsImpl(ctx: *anyopaque, root_callback: RootCallback, root_ctx: *anyopaque) void {
        // Roots are owned by the caller (Runtime operand stack +
        // locals + globals). β must-ship default: the collector
        // doesn't enumerate roots itself; callers invoke
        // `markFromRoot` directly OR pass their own walker that
        // honours this vtable. The interface signature is kept
        // intact so Mode A `zwasm_runtime_with_root_scope`
        // (ADR-0115 §4) can wire later without vtable churn.
        _ = ctx;
        _ = root_callback;
        _ = root_ctx;
    }
};

// ============================================================
// Tests
// ============================================================

const testing = std.testing;
const sections = @import("../../parse/sections.zig");

fn buildArenaedHeap(arena: *std.heap.ArenaAllocator, body: []const u8) !struct {
    heap: *Heap,
    gti: GcTypeInfos,
} {
    const a = arena.allocator();
    var types = try sections.decodeTypes(testing.allocator, body);
    defer types.deinit();
    const gti = try type_info_mod.materialiseGcTypes(a, types);
    const heap = try a.create(Heap);
    heap.* = Heap.init(a);
    return .{ .heap = heap, .gti = gti };
}

test "MarkSweepCollector: sweep over empty heap → 0 stats (10.G op_gc cycle 26)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const body = [_]u8{ 0x01, 0x5F, 0x01, 0x7F, 0x01 };
    const env = try buildArenaedHeap(&arena, &body);

    var c = MarkSweepCollector.init(env.heap, &env.gti);
    c.collector().collect();
    try testing.expectEqual(@as(u32, 0), c.last_stats.objects_seen);
    try testing.expectEqual(@as(u32, 0), c.last_stats.survivors);
    try testing.expectEqual(@as(u32, 0), c.last_stats.dead_bytes);
}

test "MarkSweepCollector: 2 struct allocs + 1 root → survivors=1, dead=struct_payload+header (10.G op_gc cycle 26)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    // struct { i32 var } → payload_size = 8; alloc size = header(8) + 8 = 16.
    const body = [_]u8{ 0x01, 0x5F, 0x01, 0x7F, 0x01 };
    const env = try buildArenaedHeap(&arena, &body);

    var c = MarkSweepCollector.init(env.heap, &env.gti);
    // Manually allocate two objects with the right header shape so
    // sweep can decode them. Use Heap.allocate + write header by hand.
    const sz: u32 = header_size + 8;
    const ref1 = try env.heap.allocate(sz);
    const hdr1: ObjectHeader = .{ .kind = .struct_, .info = 0 };
    @memcpy(env.heap.bytes[ref1 .. ref1 + header_size], std.mem.asBytes(&hdr1)[0..header_size]);
    const ref2 = try env.heap.allocate(sz);
    const hdr2: ObjectHeader = .{ .kind = .struct_, .info = 0 };
    @memcpy(env.heap.bytes[ref2 .. ref2 + header_size], std.mem.asBytes(&hdr2)[0..header_size]);

    // Mark only the first object as root.
    c.markFromRoot(ref1);
    c.collector().collect();

    try testing.expectEqual(@as(u32, 2), c.last_stats.objects_seen);
    try testing.expectEqual(@as(u32, 1), c.last_stats.survivors);
    try testing.expectEqual(sz, c.last_stats.dead_bytes);
}

test "MarkSweepCollector: array object size decoded from ArrayHeader.length (10.G op_gc cycle 26)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    // array<i32 var>; element size = 8 per slot.
    const body = [_]u8{ 0x01, 0x5E, 0x7F, 0x01 };
    const env = try buildArenaedHeap(&arena, &body);

    var c = MarkSweepCollector.init(env.heap, &env.gti);
    const length: u32 = 4;
    const total: u32 = array_header_size + length * 8;
    const ref = try env.heap.allocate(total);
    const ahdr: ArrayHeader = .{
        .header = .{ .kind = .array, .info = 0 },
        .length = length,
    };
    @memcpy(env.heap.bytes[ref .. ref + array_header_size], std.mem.asBytes(&ahdr)[0..array_header_size]);

    // Don't mark → dead.
    c.collector().collect();
    try testing.expectEqual(@as(u32, 1), c.last_stats.objects_seen);
    try testing.expectEqual(@as(u32, 0), c.last_stats.survivors);
    try testing.expectEqual(total, c.last_stats.dead_bytes);
}

test "MarkSweepCollector: mark bit cleared after sweep (10.G op_gc cycle 26)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const body = [_]u8{ 0x01, 0x5F, 0x01, 0x7F, 0x01 };
    const env = try buildArenaedHeap(&arena, &body);

    var c = MarkSweepCollector.init(env.heap, &env.gti);
    const ref = try env.heap.allocate(header_size + 8);
    const hdr: ObjectHeader = .{ .kind = .struct_, .info = 0 };
    @memcpy(env.heap.bytes[ref .. ref + header_size], std.mem.asBytes(&hdr)[0..header_size]);

    c.markFromRoot(ref);
    // Verify mark bit set before sweep.
    var pre: ObjectHeader = undefined;
    @memcpy(std.mem.asBytes(&pre)[0..header_size], env.heap.bytes[ref .. ref + header_size]);
    try testing.expect((pre.info & mark_bit_mask) != 0);

    c.collector().collect();
    var post: ObjectHeader = undefined;
    @memcpy(std.mem.asBytes(&post)[0..header_size], env.heap.bytes[ref .. ref + header_size]);
    try testing.expectEqual(@as(u32, 0), post.info & mark_bit_mask);
    // Typeidx (low 31 bits) preserved.
    try testing.expectEqual(@as(u32, 0), post.info);
}

test "MarkSweepCollector: allocObject delegates to Heap.allocate (10.G op_gc cycle 26)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const body = [_]u8{ 0x01, 0x5F, 0x01, 0x7F, 0x01 };
    const env = try buildArenaedHeap(&arena, &body);

    var c = MarkSweepCollector.init(env.heap, &env.gti);
    const col = c.collector();
    const ref = col.allocObject(16) orelse return error.UnexpectedAllocFail;
    try testing.expect(ref >= 2);
    try testing.expect(ref % 2 == 0);
}
