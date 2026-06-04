//! Register-homed scalar GPR locals — stage-1 plan (ADR-0155, D-265 Phase IV).
//!
//! A wasm local can be given a *register home* instead of a stack slot: the
//! local becomes a single function-spanning pseudo-vreg (mutable, multi-def),
//! loaded once in the prologue and read/written in-register for its whole
//! lifetime — so a loop body's `local.get`/`local.set` cost zero memory access
//! and the value crosses the loop back-edge in a register (the D-265 win).
//!
//! This module is the SINGLE SOURCE OF TRUTH for the plan. `liveness.compute`,
//! `regalloc_shape_tags`, `regalloc_compute`, and the arm64 emit driver each
//! call `plan(func)` and MUST observe the identical mapping (the lockstep
//! invariant from the spike). Because every caller re-derives the plan purely
//! from `*const ZirFunc`, the three passes cannot drift.
//!
//! ## Numbering scheme (fix A — APPEND, ADR-0155 stage 1)
//!
//! The K pseudo-vregs are given the HIGHEST vreg ids, AFTER every temporary
//! vreg liveness mints during its operand-stack walk. So temporary numbering is
//! UNCHANGED vs the un-homed model — no shift, no renumbering of any
//! block/if/else/br arithmetic in liveness. The pseudo-vreg for the r-th homed
//! local has id `n_temp + r`, where `n_temp` is the count of temporary vregs
//! (= `liveness.ranges.len - K`). Regalloc then PRIORITISES these K high-id
//! pseudo-vregs onto the low register slots (0..K-1) so they stay
//! register-resident despite their high ids.
//!
//! ## Stage gates (conservative; widened in later ADR-0155 stages)
//!
//! - **aarch64 only** — K=0 on every other arch (x86_64 parity is stage 4).
//! - **no GC/memory TRAMPOLINE op** (stage 2b) — `memory.grow`, `struct.new*`,
//!   `array.*`, `ref.test*`, `ref.cast*`, `br_on_cast*` route through a Zig
//!   trampoline whose caller-saved clobber the call-site spill/reload does not
//!   yet cover; any function containing one homes nothing. Plain calls
//!   (`.call` / `.call_indirect` / `.call_ref` / `.return_call*`) ARE allowed
//!   from stage 2: the arm64 op_call emit spills caller-saved homed locals
//!   before the BL/BLR and reloads them after (tail calls need no reload —
//!   control does not return).
//! - **scalar GPR locals only** — i32 / i64 / ref. f32/f64/v128 are FP-class
//!   (stage 3); GcRef stays slot-homed for GC-scan visibility (ADR-0155
//!   anti-regression invariant 2; reftype here means a non-GC funcref/externref
//!   which the conservative scan does not chase into registers — but to stay on
//!   the safe side we home only i32/i64, NOT ref, in stage 1).
//! - **capacity** — at most `max_homed` locals are homed (the low GPR slots
//!   reserved for homing); the rest stay slot-homed (overflow).
//!
//! Zone 1 (`src/ir/`).

const std = @import("std");
const builtin = @import("builtin");

const zir = @import("../zir.zig");

const ZirFunc = zir.ZirFunc;
const ZirOp = zir.ZirOp;
const ValType = zir.ValType;

/// Hard cap on homed locals (stage 1). Bounded by the low GPR register slots we
/// are willing to pin function-wide; leaves the remaining slots for temporaries
/// (v1 has the same trade — the first locals win registers, the rest overflow).
pub const max_homed: u32 = 6;

/// A resolved homing plan for one function. `count` pseudo-vregs are homed; the
/// homed local's absolute wasm local index is `local_idx[r]` for rank
/// `r in 0..count`. `rank_of[local_idx]` (via `rankOf`) is the inverse map.
pub const Plan = struct {
    count: u32 = 0,
    /// rank → absolute wasm local index. Only `[0..count)` is meaningful.
    local_idx: [max_homed]u32 = undefined,
    /// Absolute wasm local index → rank, or null when that local is NOT homed.
    /// Sized to the function's total local count at plan time; backed by
    /// `rank_buf`.
    rank_buf: [max_local_scan]i32 = undefined,
    n_locals: u32 = 0,

    /// Rank of a homed local, or null if `local_idx` is not register-homed.
    pub fn rankOf(self: *const Plan, local_idx: u32) ?u32 {
        if (local_idx >= self.n_locals) return null;
        const r = self.rank_buf[local_idx];
        if (r < 0) return null;
        return @intCast(r);
    }

    /// The pseudo-vreg id of a homed local given `n_temp` (the count of
    /// temporary vregs = `liveness.ranges.len - count`), or null if not homed.
    pub fn pseudoVreg(self: *const Plan, local_idx: u32, n_temp: u32) ?u32 {
        const r = self.rankOf(local_idx) orelse return null;
        return n_temp + r;
    }
};

/// Upper bound on locals we scan for homing eligibility. A function with more
/// locals than this homes nothing past the bound (the early ones still home).
const max_local_scan: u32 = 256;

/// True if the op routes through a GC/memory Zig TRAMPOLINE whose caller-saved
/// clobber is NOT covered by the arm64 op_call call-site spill/reload (stage 2b
/// territory). A function containing one of these homes nothing. Plain calls
/// (`.call` / `.call_indirect` / `.call_ref` / `.return_call*`) are deliberately
/// EXCLUDED here: from stage 2 they spill/reload caller-saved homed locals at
/// the BL/BLR emit site (`arm64/op_call.zig`).
fn isTrampolineLike(op: ZirOp) bool {
    return switch (op) {
        .@"memory.grow",
        .@"struct.new",
        .@"struct.new_default",
        .@"array.new",
        .@"array.new_default",
        .@"array.new_fixed",
        .@"array.fill",
        .@"array.copy",
        .@"array.new_data",
        .@"array.new_elem",
        .@"ref.test",
        .@"ref.test_null",
        .@"ref.cast",
        .@"ref.cast_null",
        .br_on_cast,
        .br_on_cast_fail,
        => true,
        else => false,
    };
}

/// Scalar GPR local eligible for register homing (stage 1): i32 / i64 only.
/// `ref` is excluded for GC-scan conservatism (ADR-0155 invariant 2); f32/f64
/// are FP-class (stage 3); v128 needs a V-register home (stage 3).
fn isHomeableType(ty: ValType) bool {
    return switch (ty) {
        .i32, .i64 => true,
        .f32, .f64, .v128, .ref => false,
    };
}

/// Compute the register-homing plan for `func`. Pure function of the ZirFunc;
/// every consumer (liveness / shape_tags / regalloc / emit) gets the identical
/// plan. Returns `count == 0` when homing is gated off (non-aarch64, or the
/// function contains a call-like op).
pub fn plan(func: *const ZirFunc) Plan {
    var p: Plan = .{};

    const num_params: u32 = @intCast(func.sig.params.len);
    const total_locals: u32 = num_params + func.totalLocalCount();
    p.n_locals = @min(total_locals, max_local_scan);
    var li: u32 = 0;
    while (li < p.n_locals) : (li += 1) p.rank_buf[li] = -1;

    // Gate: aarch64 only (stage 4 = x86_64 parity).
    if (builtin.target.cpu.arch != .aarch64) return p;

    // Gate: no GC/memory trampoline op in the body (stage 2b). Plain calls are
    // allowed from stage 2 (op_call spills caller-saved homed locals at the
    // BL/BLR site).
    for (func.instrs.items) |ins| {
        if (isTrampolineLike(ins.op)) return p;
    }

    // Home the first `max_homed` scalar-GPR DECLARED locals in index order.
    // Stage 1 homes declared locals (index ≥ num_params) only, NOT params: the
    // D-265 win is loop-carried declared locals (w45 $i/$a, arr_sum/fp_sum), and
    // leaving params slot-homed keeps the AAPCS64 param-marshalling ABI (+ its
    // byte-pinned tests) untouched. Param homing is a later-stage refinement.
    var local_idx: u32 = num_params;
    while (local_idx < p.n_locals and p.count < max_homed) : (local_idx += 1) {
        const ty = func.localValType(local_idx);
        if (!isHomeableType(ty)) continue;
        p.local_idx[p.count] = local_idx;
        p.rank_buf[local_idx] = @intCast(p.count);
        p.count += 1;
    }

    return p;
}

const testing = std.testing;

fn freshFunc(locals: []const ValType) ZirFunc {
    const sig: zir.FuncType = .{ .params = &.{}, .results = &.{} };
    return ZirFunc.init(0, sig, locals);
}

test "plan: homes scalar GPR locals on aarch64, gated off elsewhere" {
    var f = freshFunc(&.{ .i32, .i32, .i32 });
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 0 });
    try f.instrs.append(testing.allocator, .{ .op = .end });
    const p = plan(&f);
    if (builtin.target.cpu.arch == .aarch64) {
        try testing.expectEqual(@as(u32, 3), p.count);
        try testing.expectEqual(@as(?u32, 0), p.rankOf(0));
        try testing.expectEqual(@as(?u32, 2), p.rankOf(2));
        // pseudo-vreg id = n_temp + rank.
        try testing.expectEqual(@as(?u32, 10), p.pseudoVreg(0, 10));
        try testing.expectEqual(@as(?u32, 12), p.pseudoVreg(2, 10));
    } else {
        try testing.expectEqual(@as(u32, 0), p.count);
        try testing.expectEqual(@as(?u32, null), p.rankOf(0));
    }
}

test "plan: a GC/memory trampoline op gates homing off (stage 2b)" {
    var f = freshFunc(&.{ .i32, .i32 });
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 0 });
    try f.instrs.append(testing.allocator, .{ .op = .@"memory.grow", .payload = 0 });
    try f.instrs.append(testing.allocator, .{ .op = .end });
    const p = plan(&f);
    try testing.expectEqual(@as(u32, 0), p.count);
}

test "plan: a plain call does NOT gate homing off (stage 2)" {
    // Stage 2 (ADR-0155 D-265 Phase IV) — a function whose only call-like ops
    // are plain calls homes its declared GPR locals; op_call spills the
    // caller-saved homes around the BL/BLR.
    var f = freshFunc(&.{ .i32, .i32 });
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 0 });
    try f.instrs.append(testing.allocator, .{ .op = .call, .payload = 0 });
    try f.instrs.append(testing.allocator, .{ .op = .end });
    const p = plan(&f);
    if (builtin.target.cpu.arch == .aarch64) {
        try testing.expectEqual(@as(u32, 2), p.count);
    } else {
        try testing.expectEqual(@as(u32, 0), p.count);
    }
}

test "plan: f32/f64/v128/ref locals stay slot-homed (skipped)" {
    var f = freshFunc(&.{ .f32, .i32, .v128, .i64, ValType.funcref });
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 0 });
    try f.instrs.append(testing.allocator, .{ .op = .end });
    const p = plan(&f);
    if (builtin.target.cpu.arch == .aarch64) {
        // Only local 1 (i32) and local 3 (i64) are homeable.
        try testing.expectEqual(@as(u32, 2), p.count);
        try testing.expectEqual(@as(?u32, null), p.rankOf(0));
        try testing.expectEqual(@as(?u32, 0), p.rankOf(1));
        try testing.expectEqual(@as(?u32, null), p.rankOf(2));
        try testing.expectEqual(@as(?u32, 1), p.rankOf(3));
        try testing.expectEqual(@as(?u32, null), p.rankOf(4));
    }
}

test "plan: caps at max_homed" {
    var f = freshFunc(&([_]ValType{.i32} ** 10));
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 0 });
    try f.instrs.append(testing.allocator, .{ .op = .end });
    const p = plan(&f);
    if (builtin.target.cpu.arch == .aarch64) {
        try testing.expectEqual(max_homed, p.count);
        try testing.expectEqual(@as(?u32, null), p.rankOf(max_homed)); // beyond cap
    }
}
