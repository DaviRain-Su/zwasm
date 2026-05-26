//! Per-Store GC heap slab (ADR-0115 §1 + §5; ROADMAP §10 row 10.G).
//!
//! Cycle 3 of the 10.G-foundation bundle. Lands the minimal
//! bump-pointer allocator over an arena-backed slab. The slab is
//! a Runtime arena sub-region per ADR-0014 §6.K.2 single-allocator
//! policy (no separate libc path); `deinit` returns memory to the
//! parent arena.
//!
//! Key invariants (ADR-0115 §5):
//!   - 32-bit indexed `GcRef` (offset into slab). 4 GiB cap.
//!   - Object alignment ≥ 2 bytes (preserves low bit for i31
//!     discriminant per ADR-0116 §135-149).
//!   - `0` = null sentinel (offset 0 reserved; never allocated).
//!   - 4 KB page granularity for grow.
//!
//! Scope (deliberate; collector lives separately):
//!   - No mark/sweep / no compaction yet. The Collector vtable
//!     lands at cycle 4 (`collector_null.zig` + `collector_
//!     mark_sweep.zig`).
//!   - No write barriers — barrier-zero per ADR-0115 §3.
//!   - No root walker — Mode A default (host marks via
//!     `zwasm_runtime_with_root_scope` per §4) lands later.
//!
//! Zone 1 (`src/feature/gc/`).

const std = @import("std");

const Allocator = std.mem.Allocator;

/// 32-bit offset into a `Heap.bytes` slab; `0` = null sentinel.
/// Matches `Value.anyref` arm (added cycle 1) — both encode the
/// same GcRef view per ADR-0115 §6.
pub const GcRef = u32;

/// Null reference (offset 0). Per ADR-0115 §5 the slab reserves
/// offset 0 so this sentinel cannot collide with a real object.
pub const null_ref: GcRef = 0;

/// Per-Store contiguous slab. 32-bit cursor (offset 1..maxU32);
/// allocations bump-advance the cursor + 2-byte align. Grow
/// reallocs the backing slice via the parent arena allocator in
/// 4 KB page chunks. ADR-0115 §5.
pub const Heap = struct {
    /// Parent allocator backing `bytes`. Runtime arena per
    /// ADR-0014 §6.K.2 (so `deinit` doesn't free — the parent
    /// arena's `deinit` frees in bulk).
    parent: Allocator,
    /// Slab bytes. Grown in `page_size` increments. `bytes.ptr`
    /// is stable across grows because we use `parent.realloc`.
    bytes: []u8 = &.{},
    /// Next-free offset. Starts at 2 (offset 0 = null sentinel;
    /// offset 1 left padding to keep first object 2-byte aligned).
    cursor: u32 = 2,

    /// 4 KB grow granularity per ADR-0115 §5. Page is the slab
    /// grow unit, NOT the OS page (the slab is a sub-region of
    /// the Runtime arena which is itself mmap-backed).
    pub const page_size: u32 = 4096;

    /// Object alignment floor per ADR-0115 §5. 2 bytes preserves
    /// the low bit for i31 discriminant per ADR-0116.
    pub const min_align: u32 = 2;

    /// 4 GiB cap (maxInt(u32)) per ADR-0115 §5. Multi-Store
    /// deployment for larger heaps.
    pub const max_size: u32 = std.math.maxInt(u32);

    pub const Error = error{
        /// Heap exhausted past 4 GiB cap (or parent arena OOM).
        OutOfHeap,
    };

    pub fn init(parent: Allocator) Heap {
        return .{ .parent = parent };
    }

    /// Returns memory to the parent allocator. Per ADR-0014
    /// §6.K.2 the parent is the Runtime arena, so this is
    /// usually a no-op (arena `deinit` frees in bulk); explicit
    /// free is provided for tests and standalone use.
    pub fn deinit(self: *Heap) void {
        if (self.bytes.len > 0) self.parent.free(self.bytes);
        self.bytes = &.{};
        self.cursor = 2;
    }

    /// Bump-allocate `size` bytes from the slab, growing in
    /// 4 KB pages as needed. Returns the GcRef offset (≥ 2).
    /// Object alignment is forced to `min_align` (2 bytes) per
    /// the i31 low-bit invariant.
    pub fn allocate(self: *Heap, size: u32) Error!GcRef {
        if (size == 0) return self.cursor; // zero-size object alias
        // Align the cursor up to min_align before allocating.
        const aligned = std.mem.alignForward(u32, self.cursor, min_align);
        // Range check against 4 GiB cap with overflow protection.
        const end_widened = @addWithOverflow(aligned, size);
        if (end_widened[1] != 0 or end_widened[0] > max_size) {
            return Error.OutOfHeap;
        }
        const end = end_widened[0];
        if (end > self.bytes.len) try self.growTo(end);
        const ref: GcRef = aligned;
        self.cursor = end;
        return ref;
    }

    fn growTo(self: *Heap, min_bytes: u32) Error!void {
        // Round up to next page_size boundary.
        const new_len_u32 = std.mem.alignForward(u32, min_bytes, page_size);
        const new_len: usize = @intCast(new_len_u32);
        const new_bytes = if (self.bytes.len == 0)
            self.parent.alloc(u8, new_len) catch return Error.OutOfHeap
        else
            self.parent.realloc(self.bytes, new_len) catch return Error.OutOfHeap;
        // Zero the newly-grown tail so freshly-allocated objects
        // see a clean slate (matches Wasm GC spec init-to-default).
        @memset(new_bytes[self.bytes.len..], 0);
        self.bytes = new_bytes;
    }
};

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "Heap.init: empty slab, cursor at 2 (offset 0+1 reserved)" {
    var h = Heap.init(testing.allocator);
    defer h.deinit();
    try testing.expectEqual(@as(usize, 0), h.bytes.len);
    try testing.expectEqual(@as(u32, 2), h.cursor);
}

test "Heap.allocate: first allocation lands at offset 2 (post-sentinel)" {
    var h = Heap.init(testing.allocator);
    defer h.deinit();
    const ref = try h.allocate(16);
    try testing.expectEqual(@as(GcRef, 2), ref);
    try testing.expect(h.bytes.len >= 2 + 16);
}

test "Heap.allocate: cursor advances; never returns null_ref" {
    var h = Heap.init(testing.allocator);
    defer h.deinit();
    const r0 = try h.allocate(8);
    const r1 = try h.allocate(8);
    try testing.expect(r0 != null_ref);
    try testing.expect(r1 != null_ref);
    try testing.expect(r1 > r0);
}

test "Heap.allocate: 2-byte alignment preserves i31 low bit (ADR-0116)" {
    var h = Heap.init(testing.allocator);
    defer h.deinit();
    // Allocate an odd-size object — next ref must be even-aligned.
    _ = try h.allocate(1);
    const r1 = try h.allocate(4);
    try testing.expectEqual(@as(u32, 0), r1 % Heap.min_align);
}

test "Heap.allocate: grow in 4 KB pages" {
    var h = Heap.init(testing.allocator);
    defer h.deinit();
    _ = try h.allocate(1);
    // First grow rounds up to one page (4096 B).
    try testing.expectEqual(@as(usize, Heap.page_size), h.bytes.len);
    // Trigger second-page grow.
    _ = try h.allocate(Heap.page_size);
    try testing.expect(h.bytes.len >= 2 * Heap.page_size);
}

test "Heap.allocate: returns OutOfHeap when size > 4 GiB cap" {
    var h = Heap.init(testing.allocator);
    defer h.deinit();
    // Past the 4 GiB cap.
    try testing.expectError(Heap.Error.OutOfHeap, h.allocate(Heap.max_size));
}

test "Heap.deinit: explicit free returns bytes to parent" {
    var h = Heap.init(testing.allocator);
    _ = try h.allocate(8);
    try testing.expect(h.bytes.len > 0);
    h.deinit();
    try testing.expectEqual(@as(usize, 0), h.bytes.len);
    try testing.expectEqual(@as(u32, 2), h.cursor);
}
