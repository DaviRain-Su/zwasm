//! Diagnostic M3-a trace ringbuffer (per ADR-0028).
//!
//! Per-thread fixed-size ring buffer of structured `TraceEntry`
//! records. Used to capture compile-time and (eventually) trap-
//! time events for post-mortem diagnosis without per-event
//! syscall overhead.
//!
//! M3-a-1 scope (this commit): ringbuffer infrastructure +
//! `bounds` category (compile-time write at memory-op emit
//! sites). Trap-time write from JIT stub is M3-a-2 (separate
//! chunk; requires trap stub → drain helper call calling-
//! convention coordination).
//!
//! Compile-time gate: `build_options.trace_ringbuffer` controls
//! whether write functions execute meaningfully or fold to
//! no-ops. Per ROADMAP §A12 the gate is **not** a runtime `if`
//! in hot dispatch paths; it's a `comptime` branch consumed by
//! every write site, so release builds with `-Dtrace-ringbuffer=
//! false` (default) emit zero trace code.
//!
//! Storage is `threadlocal` per ADR-0028 D-021 cross-reference.
//! Phase 14 multi-thread re-architecture happens alongside
//! Diagnostic's threadlocal slot (same reasoning, same migration).
//!
//! Zone 1 (`src/diagnostic/`).

const std = @import("std");
const build_options = @import("build_options");

/// Whether the trace ringbuffer is compiled in. Off by default
/// (see `build.zig` `-Dtrace-ringbuffer` flag). When false, all
/// write functions fold to no-ops via `comptime` branches and
/// the threadlocal storage slot drops out as dead state.
pub const enabled: bool = build_options.trace_ringbuffer;

/// Trace event category. 4-bit encoding (16 slots reserved;
/// 6 used today, 10 spare for M3-a-2 / M3-b / M3-c).
pub const Category = enum(u4) {
    /// Per-memory-op emit (M3-a-1: bounds-check site offset).
    bounds = 0,
    /// Per-trap entry (M3-a-2: trap stub records kind + pc).
    trap = 1,
    /// Per-allocation-decision (M3-b).
    regalloc = 2,
    /// Per-function compile boundary (M3-b).
    jit = 3,
    /// Per-call boundary interp ↔ JIT (M3-c).
    exec = 4,
    /// Per-ZIR-instr (M3-c; high overhead).
    regir = 5,
    _,
};

/// Per-category event tag. 4-bit; layout depends on Category.
/// `bounds` events use only `.emit_check`; future categories
/// add their own variants.
pub const Event = enum(u4) {
    emit_check = 0,
    _,
};

/// 8-byte packed entry (one cache line per 8 entries).
///
/// `payload_a` / `payload_b` semantics are category-specific;
/// the trace dump consumer interprets them via Category +
/// Event. For Category=.bounds Event=.emit_check:
///   payload_a = func_idx (u24; truncated if Wasm module has
///               > 16M funcs — far beyond any realistic Wasm
///               module size)
///   payload_b = byte_offset_within_func (u32; full 4 GiB
///               function body addressable, no truncation)
///
/// Layout (64 bits total): cat(4) + event(4) + payload_a(24) +
/// payload_b(32) = 64. Timestamp / cycle counter is dropped at
/// M3-a-1 in favour of `head` ordering (see `writeEntry` /
/// `drain` for chronological reconstruction).
pub const TraceEntry = packed struct(u64) {
    category: Category,
    event: Event,
    payload_a: u24,
    payload_b: u32,
};

/// Ring buffer capacity in entries. 32 = 256 bytes, fits 4
/// cache lines on 64-byte-line machines. Sized to capture
/// the typical "last 8 events before trap" window 4× over.
pub const capacity: usize = 32;

/// Per-thread ring buffer state. Lives only when `enabled`
/// (otherwise dead state, optimised out by LLVM).
const Ring = struct {
    entries: [capacity]TraceEntry,
    /// Total writes since last `clear` — the consumer mod-`capacity`
    /// to find the slot. Wraps on u64 overflow (≈ 5 × 10^11
    /// years at 1 GHz; not a concern).
    head: u64,
};

threadlocal var ring: Ring = .{
    .entries = @splat(.{
        .category = .bounds,
        .event = .emit_check,
        .payload_a = 0,
        .payload_b = 0,
    }),
    .head = 0,
};

/// Write a single entry into the per-thread ring. Compile-time
/// no-op when `enabled == false`. Cold-path: trace writes happen
/// at compile sites (M3-a-1) or trap sites (M3-a-2) — never on
/// the JIT-execution hot path.
inline fn writeEntry(entry: TraceEntry) void {
    if (comptime !enabled) return;
    const slot = ring.head % capacity;
    ring.entries[slot] = entry;
    ring.head += 1;
}

/// M3-a-1: record a memory-op bounds-check emit site. Called
/// from ARM64 `op_memory.emitMemOp` and x86_64 `emit.emitMemOp`
/// after the JAE/B.HI fixup is appended.
///
/// `func_idx` is truncated to u24 (16 M funcs); `byte_offset_in
/// _func` keeps full u32 (4 GiB).
pub inline fn writeBounds(func_idx: u32, byte_offset_in_func: u32) void {
    if (comptime !enabled) return;
    writeEntry(.{
        .category = .bounds,
        .event = .emit_check,
        .payload_a = @truncate(func_idx),
        .payload_b = byte_offset_in_func,
    });
}

/// Reset the per-thread ring. Called by tests + by future
/// host entry points before each guest-call boundary.
pub fn clear() void {
    if (comptime !enabled) return;
    ring.head = 0;
}

/// Snapshot the most recent `min(max, dst.len, head, capacity)`
/// entries in chronological order (oldest of the snapshot first,
/// newest last — i.e. the LAST events before drain). Returned
/// slice is a copy into `dst` to avoid threadlocal-pointer
/// leakage; caller owns `dst`.
///
/// **Trap diagnosis pattern**: when `dst` is smaller than the
/// total writes, the OLDEST entries are dropped and the NEWEST
/// fill `dst`. This matches the typical "show me the last N
/// events before the trap" use case.
///
/// Returns the count actually filled; 0 when disabled or empty.
pub fn drain(dst: []TraceEntry, max: usize) usize {
    if (comptime !enabled) return 0;
    const written = ring.head;
    const want = @min(@min(max, dst.len), @min(written, capacity));
    if (want == 0) return 0;
    // Oldest-first: the slot N entries before head is at
    // (head - N) mod capacity. We walk forward from there.
    const start_offset = written - want;
    var i: usize = 0;
    while (i < want) : (i += 1) {
        const slot = (start_offset + i) % capacity;
        dst[i] = ring.entries[slot];
    }
    return want;
}

/// Total entries written since last `clear` (saturates at u64
/// max). Useful for tests asserting "exactly N writes happened".
pub fn writeCount() u64 {
    if (comptime !enabled) return 0;
    return ring.head;
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "trace: enabled flag matches build_options" {
    try testing.expectEqual(build_options.trace_ringbuffer, enabled);
}

test "trace: writeBounds + drain captures the event" {
    if (!enabled) return error.SkipZigTest;
    clear();
    writeBounds(7, 0x100);
    writeBounds(7, 0x150);
    var buf: [4]TraceEntry = undefined;
    const n = drain(&buf, 4);
    try testing.expectEqual(@as(usize, 2), n);
    try testing.expectEqual(@as(u24, 7), buf[0].payload_a);
    try testing.expectEqual(@as(u32, 0x100), buf[0].payload_b);
    try testing.expectEqual(Category.bounds, buf[0].category);
    try testing.expectEqual(@as(u32, 0x150), buf[1].payload_b);
}

test "trace: ring wraps after capacity entries" {
    if (!enabled) return error.SkipZigTest;
    clear();
    var i: u32 = 0;
    while (i < capacity + 5) : (i += 1) {
        writeBounds(0, i);
    }
    try testing.expectEqual(@as(u64, capacity + 5), writeCount());
    var buf: [capacity]TraceEntry = undefined;
    const n = drain(&buf, capacity);
    try testing.expectEqual(capacity, n);
    // Oldest captured entry has byte_offset = 5 (slots 0..4 were overwritten).
    try testing.expectEqual(@as(u32, 5), buf[0].payload_b);
    // Newest captured entry has byte_offset = capacity + 4.
    try testing.expectEqual(@as(u32, capacity + 4), buf[capacity - 1].payload_b);
}

test "trace: drain into smaller dst returns newest N (last events before trap)" {
    if (!enabled) return error.SkipZigTest;
    clear();
    writeBounds(0, 1);
    writeBounds(0, 2);
    writeBounds(0, 3);
    var buf: [2]TraceEntry = undefined;
    const n = drain(&buf, 2);
    try testing.expectEqual(@as(usize, 2), n);
    // Newest 2 of 3 (trap diagnosis preference): byte_offsets 2 and 3.
    try testing.expectEqual(@as(u32, 2), buf[0].payload_b);
    try testing.expectEqual(@as(u32, 3), buf[1].payload_b);
}

test "trace: clear resets writeCount + drain" {
    if (!enabled) return error.SkipZigTest;
    clear();
    writeBounds(0, 100);
    writeBounds(0, 200);
    try testing.expectEqual(@as(u64, 2), writeCount());
    clear();
    try testing.expectEqual(@as(u64, 0), writeCount());
    var buf: [4]TraceEntry = undefined;
    try testing.expectEqual(@as(usize, 0), drain(&buf, 4));
}

test "trace: TraceEntry is exactly 8 bytes (packed struct contract)" {
    try testing.expectEqual(@as(usize, 8), @sizeOf(TraceEntry));
}

// Integration test: verifies the JIT emit paths (both backends)
// actually invoke trace.writeBounds when a memory op is compiled.
// Skipped under default build (`-Dtrace-ringbuffer=false`); the
// disabled state is independently covered by the call-site
// `comptime` branches.
test "trace: JIT emit invokes writeBounds for i32.load (integration, both backends)" {
    if (!enabled) return error.SkipZigTest;
    const builtin = @import("builtin");
    const zir = @import("../ir/zir.zig");
    const ZirFunc = zir.ZirFunc;
    const regalloc = @import("../engine/codegen/shared/regalloc.zig");

    // Pick the active backend's compile() based on host arch. The
    // Wasm fixture is the same for both; the bytes differ but the
    // `trace.writeBounds` call should fire identically.
    const compile = switch (builtin.cpu.arch) {
        .aarch64 => @import("../engine/codegen/arm64/emit.zig").compile,
        .x86_64 => @import("../engine/codegen/x86_64/emit.zig").compile,
        else => return error.SkipZigTest,
    };
    const deinit = switch (builtin.cpu.arch) {
        .aarch64 => @import("../engine/codegen/arm64/emit.zig").deinit,
        .x86_64 => @import("../engine/codegen/x86_64/emit.zig").deinit,
        else => return error.SkipZigTest,
    };

    clear();

    const sig: zir.FuncType = .{ .params = &.{}, .results = &.{.i32} };
    var f = ZirFunc.init(42, sig, &.{}); // func_idx = 42
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 0 });
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.load", .payload = 0 });
    try f.instrs.append(testing.allocator, .{ .op = .@"end" });
    f.liveness = .{ .ranges = &[_]zir.LiveRange{
        .{ .def_pc = 0, .last_use_pc = 1 },
        .{ .def_pc = 1, .last_use_pc = 2 },
    } };
    const slots = [_]u16{ 0, 0 };
    const alloc: regalloc.Allocation = .{ .slots = &slots, .n_slots = 1 };
    const out = try compile(testing.allocator, &f, alloc, &.{}, &.{}, 0);
    defer deinit(testing.allocator, out);

    try testing.expectEqual(@as(u64, 1), writeCount());
    var buf: [4]TraceEntry = undefined;
    const n = drain(&buf, 4);
    try testing.expectEqual(@as(usize, 1), n);
    try testing.expectEqual(Category.bounds, buf[0].category);
    try testing.expectEqual(Event.emit_check, buf[0].event);
    try testing.expectEqual(@as(u24, 42), buf[0].payload_a);
    try testing.expect(buf[0].payload_b > 0); // some non-trivial fixup byte offset
}
