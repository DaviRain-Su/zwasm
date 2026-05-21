//! Regalloc post-condition verifier. Extracted from `regalloc.zig`
//! per ADR-0097 (D-141 sweep). `verifyWith` walks the allocation
//! output and asserts:
//!   1. slot-count consistency,
//!   2. distinct slots for overlapping live ranges,
//!   3. (ADR-0077 fence) no vreg's slot id falls in an op's
//!      scratch reservation set across the op's PC range.
//!
//! The `verify` thin wrapper calls `verifyWith(.., null)` so
//! pre-ADR-0077 callers are bit-for-bit unaffected.

const std = @import("std");
const zir = @import("../../../ir/zir.zig");
const regalloc = @import("regalloc.zig");

const ZirFunc = zir.ZirFunc;
const Allocation = regalloc.Allocation;
const ScratchReservationFn = regalloc.ScratchReservationFn;

pub const VerifyError = error{
    SlotsLengthMismatch,
    SlotIndexExceedsCount,
    OverlappingVregsShareSlot,
    /// ADR-0077 — a live vreg's assigned slot id falls inside an
    /// op's `op_scratch_reservation_table` set across the op's
    /// PC range, meaning the op handler's internal scratch
    /// clobber would corrupt the vreg's value mid-emit. Surfaces
    /// only when `verifyWith` is called with a non-null
    /// `scratch_reservations` fence — `verify` (the thin null
    /// wrapper) never returns this variant.
    OpScratchOverlap,
};

/// Post-condition predicate: assert no two overlapping live
/// ranges share a slot. (Naive O(n²) walker — Phase 7.1 scope
/// caps max_operand_stack at 1024, so at most ~1024 vregs in
/// straight-line code). Interval-tree refinement is a §9.7 / 7.3
/// follow-up if a profile demands it.
pub fn verify(func: *const ZirFunc, alloc: Allocation) VerifyError!void {
    return verifyWith(func, alloc, null);
}

/// `verify` + ADR-0077 op-scratch-overlap post-condition.
///
/// When `scratch_reservations` is non-null, additionally scans
/// every live vreg's strict-interior PC range and emits
/// `OpScratchOverlap` if the vreg's assigned slot id falls in
/// the op's reservation set. PC shape mirrors `computeWith`'s
/// fence (`def_pc < pc < last_use_pc`), so verification fires
/// iff the walker should have skipped the slot id but didn't —
/// the canonical regression check for a buggy fence
/// integration. Spill slots (id ≥ `force_spill_threshold`,
/// derived from `alloc.max_reg_slots_gpr`) are exempt: they
/// never resolve to a clobberable register.
pub fn verifyWith(
    func: *const ZirFunc,
    alloc: Allocation,
    scratch_reservations: ?ScratchReservationFn,
) VerifyError!void {
    const live = func.liveness orelse return;
    if (alloc.slots.len != live.ranges.len) return VerifyError.SlotsLengthMismatch;
    for (alloc.slots) |s| {
        if (s >= alloc.n_slots) return VerifyError.SlotIndexExceedsCount;
    }
    for (live.ranges, 0..) |a, ai| {
        for (live.ranges[ai + 1 ..], ai + 1..) |b, bi| {
            // Strict half-open overlap: [a.def, a.use) ∩ [b.def, b.use).
            const overlaps = (a.def_pc < b.last_use_pc) and (b.def_pc < a.last_use_pc);
            if (overlaps and alloc.slots[ai] == alloc.slots[bi]) {
                return VerifyError.OverlappingVregsShareSlot;
            }
        }
    }
    if (scratch_reservations) |fence| {
        const force_spill_threshold: u16 = alloc.max_reg_slots_gpr;
        for (live.ranges, 0..) |r, vreg| {
            const sid = alloc.slots[vreg];
            if (sid >= force_spill_threshold) continue;
            var pc: u32 = r.def_pc + 1;
            while (pc < r.last_use_pc) : (pc += 1) {
                if (pc >= func.instrs.items.len) break;
                for (fence(func.instrs.items[pc].op)) |reserved_sid| {
                    if (sid == reserved_sid) return VerifyError.OpScratchOverlap;
                }
            }
        }
    }
}

const testing = std.testing;
const LiveRange = zir.LiveRange;

fn freshFunc() ZirFunc {
    const sig: zir.FuncType = .{ .params = &.{}, .results = &.{} };
    return ZirFunc.init(0, sig, &.{});
}

/// Local copy of the regalloc-side fence-table stub used by the
/// compute-side fence tests. Reserves slots {0..4} for
/// `.@"table.fill"` (mirrors the production reservation set per
/// the B119 live-scratch census). Kept duplicated rather than
/// pub-ifying the regalloc.zig test helper.
fn testFenceTableFill(op: zir.ZirOp) []const u16 {
    const reservation = [_]u16{ 0, 1, 2, 3, 4 };
    return if (op == .@"table.fill") &reservation else &.{};
}

test "verify: rejects allocation with slot index >= n_slots" {
    var f = freshFunc();
    defer f.deinit(testing.allocator);
    const ranges = [_]LiveRange{.{ .def_pc = 0, .last_use_pc = 1 }};
    f.liveness = .{ .ranges = &ranges };
    const bad_slots = [_]u16{5};
    const bad: Allocation = .{ .slots = &bad_slots, .n_slots = 1 };
    try testing.expectError(VerifyError.SlotIndexExceedsCount, verify(&f, bad));
}

test "verify: rejects mismatched slot/range lengths" {
    var f = freshFunc();
    defer f.deinit(testing.allocator);
    const ranges = [_]LiveRange{.{ .def_pc = 0, .last_use_pc = 1 }};
    f.liveness = .{ .ranges = &ranges };
    const bad_slots = [_]u16{ 0, 1 };
    const bad: Allocation = .{ .slots = &bad_slots, .n_slots = 2 };
    try testing.expectError(VerifyError.SlotsLengthMismatch, verify(&f, bad));
}

test "verify: rejects overlapping ranges sharing a slot" {
    var f = freshFunc();
    defer f.deinit(testing.allocator);
    const ranges = [_]LiveRange{
        .{ .def_pc = 0, .last_use_pc = 5 },
        .{ .def_pc = 1, .last_use_pc = 4 },
    };
    f.liveness = .{ .ranges = &ranges };
    const bad_slots = [_]u16{ 0, 0 };
    const bad: Allocation = .{ .slots = &bad_slots, .n_slots = 1 };
    try testing.expectError(VerifyError.OverlappingVregsShareSlot, verify(&f, bad));
}

test "verifyWith: detects op-scratch overlap on hand-broken allocation" {
    // Same shape as the fence test, but inject an allocation that
    // bypasses the fence (slot 0 for a vreg crossing table.fill).
    // verifyWith with the fence active must catch it; verify
    // without the fence accepts it (back-compat).
    var f = freshFunc();
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .nop });
    try f.instrs.append(testing.allocator, .{ .op = .@"table.fill" });
    try f.instrs.append(testing.allocator, .{ .op = .nop });
    try f.instrs.append(testing.allocator, .{ .op = .nop });
    const ranges = [_]LiveRange{
        .{ .def_pc = 0, .last_use_pc = 3 },
    };
    f.liveness = .{ .ranges = &ranges };

    const broken_slots = [_]u16{0};
    const broken: Allocation = .{ .slots = &broken_slots, .n_slots = 1 };
    try testing.expectError(VerifyError.OpScratchOverlap, verifyWith(&f, broken, testFenceTableFill));
    // Back-compat: verify (null fence) accepts the same allocation.
    try verify(&f, broken);
}

test "verifyWith: spill-region slot ids are exempt from the post-condition" {
    // A vreg parked in the spill region (slot >= max_reg_slots_gpr)
    // cannot collide with op-internal scratch — the spill stage
    // regs are X14/X15, outside `allocatable_gprs`. Verifier
    // must not flag this.
    var f = freshFunc();
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .nop });
    try f.instrs.append(testing.allocator, .{ .op = .@"table.fill" });
    try f.instrs.append(testing.allocator, .{ .op = .nop });
    const ranges = [_]LiveRange{
        .{ .def_pc = 0, .last_use_pc = 2 },
    };
    f.liveness = .{ .ranges = &ranges };

    // Slot 9 is spill territory under the default max_reg_slots_gpr=8.
    const spilled_slots = [_]u16{9};
    const spilled: Allocation = .{ .slots = &spilled_slots, .n_slots = 10 };
    try verifyWith(&f, spilled, testFenceTableFill);
}
