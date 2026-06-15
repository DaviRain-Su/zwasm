//! WASI-0.3 / Component-Model async runtime (campaign D-335 Unit D; ADR-0187).
//!
//! Stackless callback-ABI model on zwasm's synchronous engine — NO fibers. This
//! module is the Zone-1 pure-data core: the per-component stream/future **handle
//! table** (the table Unit C's i32 ABI handles index into), the `CopyState`
//! machine, and the `ReturnCode` packing. The rendezvous copy logic, waitable
//! sets, subtasks, and the callback event loop land in later chunks (β–η per
//! ADR-0187); none of those import the engine — the Zone-3 host drives the loop.
//!
//! The handle-table discipline mirrors `resource_table.zig`: dense array + free
//! list, index 0 reserved as a `None` sentinel (a valid handle is ≥ 1), and
//! `remove` tombstones a slot so a double-drop / use-after-drop traps on the
//! next access.

const std = @import("std");

const Allocator = std.mem.Allocator;

/// Spec `Table.MAX_LENGTH` — leaves the high 4 bits of a handle free for guest
/// tagging (shared with the resource handle table).
pub const MAX_LENGTH: u32 = (1 << 28) - 1;

pub const Error = error{
    /// Handle index out of bounds, the reserved 0 sentinel, or a freed
    /// (tombstoned) slot — covers use-after-drop / double-drop.
    InvalidHandle,
    /// The table reached `MAX_LENGTH`.
    TableFull,
    OutOfMemory,
};

/// Copy-state of a stream/future end (`CanonicalABI.md` §Stream State). The
/// transitions (idle → async_copying → done, + cancelling) are driven by the
/// rendezvous logic in a later chunk; α only needs the enum + the idle default.
pub const CopyState = enum { idle, sync_copying, async_copying, cancelling_copy, done };

/// An async builtin's return value (`CanonicalABI.md`; wasmtime
/// `futures_and_streams.rs`). `Blocked` is the all-ones sentinel; the others
/// pack a 4-bit code in the low bits and an item count in the high 28 bits
/// (count is always 0 for futures — at most one value).
pub const ReturnCode = union(enum) {
    blocked,
    completed: u28,
    dropped: u28,
    cancelled: u28,

    pub fn encode(self: ReturnCode) u32 {
        return switch (self) {
            .blocked => 0xffff_ffff,
            .completed => |n| @as(u32, n) << 4, // code 0
            .dropped => |n| (@as(u32, n) << 4) | 1,
            .cancelled => |n| (@as(u32, n) << 4) | 2,
        };
    }
};

pub const EndKind = enum { stream, future };
pub const EndSide = enum { readable, writable };

/// One stream/future **end** in the handle table. `elem_type` is the element
/// (stream) / value (future) WIT type index, or null for a payload-less
/// `stream`/`future`. The shared rendezvous buffer joining the two ends lands
/// in chunk β.
pub const StreamFutureEnd = struct {
    kind: EndKind,
    side: EndSide,
    elem_type: ?u32,
    state: CopyState = .idle,
};

/// The per-component stream/future handle table (ADR-0187). Index 0 is the
/// reserved `None` sentinel; holes are `null` and reused via the free list.
pub const StreamFutureTable = struct {
    slots: std.ArrayList(?StreamFutureEnd),
    free: std.ArrayList(u32),
    alloc: Allocator,

    pub fn init(alloc: Allocator) Error!StreamFutureTable {
        var slots: std.ArrayList(?StreamFutureEnd) = .empty;
        errdefer slots.deinit(alloc);
        try slots.append(alloc, null); // reserve index 0
        return .{ .slots = slots, .free = .empty, .alloc = alloc };
    }

    pub fn deinit(self: *StreamFutureTable) void {
        self.slots.deinit(self.alloc);
        self.free.deinit(self.alloc);
    }

    /// `Table.add` — reuse a free hole or grow; returns the handle index (≥ 1).
    pub fn add(self: *StreamFutureTable, end: StreamFutureEnd) Error!u32 {
        if (self.free.pop()) |i| {
            self.slots.items[i] = end;
            return i;
        }
        const i: u32 = @intCast(self.slots.items.len);
        if (i > MAX_LENGTH) return Error.TableFull;
        try self.slots.append(self.alloc, end);
        return i;
    }

    /// `Table.get` — bounds + hole check (the trap source for stale handles).
    pub fn get(self: *StreamFutureTable, i: u32) Error!*StreamFutureEnd {
        if (i == 0 or i >= self.slots.items.len) return Error.InvalidHandle;
        if (self.slots.items[i] == null) return Error.InvalidHandle;
        return &self.slots.items[i].?;
    }

    /// `Table.remove` — tombstone the slot + push the hole to the free list.
    pub fn remove(self: *StreamFutureTable, i: u32) Error!StreamFutureEnd {
        const end = (try self.get(i)).*;
        self.slots.items[i] = null;
        try self.free.append(self.alloc, i);
        return end;
    }
};

// ============================================================
// Tests
// ============================================================
const testing = std.testing;

test "ReturnCode packs per the canonical-ABI encoding" {
    try testing.expectEqual(@as(u32, 0xffff_ffff), (@as(ReturnCode, .blocked)).encode());
    try testing.expectEqual(@as(u32, 3 << 4), (ReturnCode{ .completed = 3 }).encode());
    try testing.expectEqual(@as(u32, (5 << 4) | 1), (ReturnCode{ .dropped = 5 }).encode());
    try testing.expectEqual(@as(u32, (2 << 4) | 2), (ReturnCode{ .cancelled = 2 }).encode());
    // futures carry a zero count → just the code in the low bits.
    try testing.expectEqual(@as(u32, 0), (ReturnCode{ .completed = 0 }).encode());
}

test "stream/future end table: add/get/remove lifecycle + index-0 reserved" {
    var t = try StreamFutureTable.init(testing.allocator);
    defer t.deinit();

    const h = try t.add(.{ .kind = .stream, .side = .readable, .elem_type = 5 });
    try testing.expect(h >= 1); // a valid handle is never the 0 sentinel
    const end = try t.get(h);
    try testing.expectEqual(EndKind.stream, end.kind);
    try testing.expectEqual(EndSide.readable, end.side);
    try testing.expectEqual(@as(?u32, 5), end.elem_type);
    try testing.expectEqual(CopyState.idle, end.state);

    // index 0 is the reserved None sentinel.
    try testing.expectError(Error.InvalidHandle, t.get(0));

    // remove tombstones → use-after-drop / double-drop trap.
    _ = try t.remove(h);
    try testing.expectError(Error.InvalidHandle, t.get(h));
    try testing.expectError(Error.InvalidHandle, t.remove(h));

    // a freed slot is reused (free list) for the next add.
    const h2 = try t.add(.{ .kind = .future, .side = .writable, .elem_type = null });
    try testing.expectEqual(h, h2);
    try testing.expectEqual(EndKind.future, (try t.get(h2)).kind);
}
