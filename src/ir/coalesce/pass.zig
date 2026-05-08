//! Post-regalloc slot-aliasing coalescer (§9.8b / 8b.1 per
//! ADR-0035).
//!
//! Side-table metadata pass: walks the ZIR instr stream after
//! regalloc has assigned slots and records `CoalesceRecord`
//! entries for MOV-shaped emit sites where `slots[src_vreg]
//! == slots[dst_vreg]` and the alias is safe to elide. The
//! emit pass queries `func.coalesced_movs` before each MOV
//! emission and skips redundant slots.
//!
//! **Scaffolding scope (8b.1-c, this commit)**:
//! framework only — populates `func.coalesced_movs` with an
//! empty slice. Real detection logic + emit-side query
//! mechanism lands incrementally in 8b.1-d alongside
//! bench-delta evidence per ADR-0032's bench-driven
//! discipline. The 8b.1-a survey at
//! `private/notes/p8-8b1-coalescer-survey.md` identified the
//! candidate ZirOp catalogue (`local.tee` post-regalloc,
//! end-of-block multi-value merges, return-value marshalling
//! from `end`, call-arg setup); this MVP intentionally ships
//! ZERO detected records to keep the pass-frame change
//! surgical. Subsequent chunks layer in detection per-op.
//!
//! Caller-owned: `func.coalesced_movs` slice must be freed
//! via `deinitArtifacts` before `func.deinit` (mirror of
//! `src/ir/hoist/pass.zig:deinitArtifacts`).
//!
//! Zone 1 (`src/ir/`).

const std = @import("std");

const zir = @import("../zir.zig");
const regalloc = @import("../../engine/codegen/shared/regalloc.zig");

const Allocator = std.mem.Allocator;
const ZirFunc = zir.ZirFunc;
const CoalesceRecord = zir.CoalesceRecord;

pub const Error = error{OutOfMemory};

/// Run the coalescer pass. Pre-conditions: `regalloc.compute`
/// has populated `alloc.slots[]`. Post-condition:
/// `func.coalesced_movs` slot installed (may be empty —
/// scaffolding scope per `pass.zig` module doc).
pub fn run(allocator: Allocator, func: *ZirFunc, alloc: regalloc.Allocation) Error!void {
    _ = alloc; // reserved for 8b.1-d detection logic

    // 8b.1-c MVP: install an empty records slice. The
    // detection-loop scaffolding belongs here in subsequent
    // chunks (8b.1-d). Walking `func.instrs.items` and
    // selecting from the candidate ZirOp catalogue
    // (`local.tee` post-regalloc, `end` merge sites, call-arg
    // marshalling sites) is bench-delta-gated work — without
    // detected records, the bench-delta sub-step (Step 5b per
    // LOOP.md) reports 0% movement, which is informational
    // baseline data.
    var records: std.ArrayList(CoalesceRecord) = .empty;
    errdefer records.deinit(allocator);

    func.coalesced_movs = try records.toOwnedSlice(allocator);
}

/// Free `func.coalesced_movs`. No-op when slot is null or
/// empty. Called by `compile.zig:deinitFuncResult` symmetric
/// to `hoist.deinitArtifacts`.
pub fn deinitArtifacts(allocator: Allocator, func: *ZirFunc) void {
    if (func.coalesced_movs) |records| {
        if (records.len != 0) allocator.free(records);
        func.coalesced_movs = null;
    }
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "coalesce.run: scaffolding installs empty records on a tiny ZirFunc" {
    const sig: zir.FuncType = .{ .params = &.{}, .results = &.{.i32} };
    var f = ZirFunc.init(0, sig, &.{});
    defer f.deinit(testing.allocator);
    defer deinitArtifacts(testing.allocator, &f);

    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 42 });
    try f.instrs.append(testing.allocator, .{ .op = .end });

    const slots = [_]u16{0};
    const a: regalloc.Allocation = .{ .slots = &slots, .n_slots = 1 };

    try testing.expect(f.coalesced_movs == null);
    try run(testing.allocator, &f, a);
    try testing.expect(f.coalesced_movs != null);
    try testing.expectEqual(@as(usize, 0), f.coalesced_movs.?.len);
}

test "coalesce.deinitArtifacts: no-op on null slot" {
    const sig: zir.FuncType = .{ .params = &.{}, .results = &.{} };
    var f = ZirFunc.init(0, sig, &.{});
    defer f.deinit(testing.allocator);

    try testing.expect(f.coalesced_movs == null);
    deinitArtifacts(testing.allocator, &f);
    try testing.expect(f.coalesced_movs == null);
}

test "coalesce.deinitArtifacts: frees populated records" {
    const sig: zir.FuncType = .{ .params = &.{}, .results = &.{} };
    var f = ZirFunc.init(0, sig, &.{});
    defer f.deinit(testing.allocator);

    const records = try testing.allocator.alloc(CoalesceRecord, 2);
    records[0] = .{ .instr_pc = 5, .slot = 3, .reason = .same_slot_alias };
    records[1] = .{ .instr_pc = 12, .slot = 7, .reason = .same_slot_alias };
    f.coalesced_movs = records;

    deinitArtifacts(testing.allocator, &f);
    try testing.expect(f.coalesced_movs == null);
}
