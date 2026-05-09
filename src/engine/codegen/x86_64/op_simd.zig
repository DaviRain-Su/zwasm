//! x86_64 emit pass — SIMD-128 op handlers (§9.7 / 9.7-a per
//! ADR-0041).
//!
//! Mirrors the role of `arm64/op_simd.zig` for the SSE2 / SSE4.1
//! lowering of v128 ops. 9.7-a foundation chunk wires a single
//! representative binop (`i32x4.add` via PADDD) into the emit
//! dispatch to validate the encoder + regalloc shape-tag pipeline
//! end-to-end on x86_64. The shape-tag pipeline itself
//! (`engine/codegen/shared/regalloc.populateShapeTags`) is shared
//! across arches per ADR-0041 §"Decision" / 2 and needs no
//! x86_64-side wiring.
//!
//! 9.7-a scope:
//!
//! - `emitI32x4Add` — pop 2 v128, push 1 v128. `MOVAPS dst, lhs`
//!   then `PADDD dst, rhs`. v128 reg-reg copy uses the existing
//!   `encMovapsXmmXmm` (0F 28 /r): MOVAPS and MOVDQA are
//!   interchangeable for register-to-register moves on every
//!   shipped Intel/AMD micro-architecture.
//!
//! Out of scope (defers to 9.7-b+):
//!
//! - v128 spill helpers (16-byte stride MOVDQU). The existing
//!   `gpr.xmmLoadSpilled` / `xmmDefSpilled` use 8-byte MOVSD
//!   which truncates the upper 64 bits of an XMM. Spilled v128
//!   vregs therefore return `Error.SlotOverflow` via
//!   `gpr.resolveXmm` until the 16-byte spill helpers land.
//! - v128.const / v128.load / v128.store / splat / extract_lane.
//!   Without a producer (splat / load / const), the integration
//!   test for `emitI32x4Add` exercises only the handler in
//!   isolation against a synthetic regalloc state — same shape
//!   as ARM64 §9.5-b-iii's foundation pattern.
//! - Other SIMD binary arith (PSUBD, PMULLD, etc.) — same shape
//!   as `emitI32x4Add`, queued for 9.7-b's bundled binop chunk.
//!
//! Zone 2 (`src/engine/codegen/x86_64/`) — must NOT import
//! `src/engine/codegen/arm64/` per ROADMAP §A3 (Zone-2 inter-arch
//! isolation).

const std = @import("std");

const regalloc = @import("../shared/regalloc.zig");
const inst = @import("inst.zig");
const gpr = @import("gpr.zig");
const types = @import("types.zig");

const Allocator = std.mem.Allocator;
const Error = types.Error;

/// Wasm spec §4.4.4 (i32x4.add) — pop two v128, push their
/// element-wise 32-bit sum across the four lanes (wraparound).
/// x86_64 lowering: `MOVAPS dst, lhs` then `PADDD dst, rhs`
/// (Intel SDM Vol 2 PADDD, opcode 0x66 0x0F 0xFE /r). The MOVAPS
/// is elided when the regalloc happens to place dst on the same
/// XMM as lhs (the in-place case; rare with fresh-vreg-per-op
/// allocation but cheap to skip).
///
/// Spilled v128 vregs surface as `Error.SlotOverflow` from
/// `gpr.resolveXmm` — the 16-byte spill helpers land in 9.7-c.
/// Until then, functions whose v128 vregs all fit in
/// `abi.allocatable_xmms` (XMM8..XMM13, 6 slots) compile cleanly;
/// over-pressure functions return early.
pub fn emitI32x4Add(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    pushed_vregs: *std.ArrayList(u32),
    next_vreg: *u32,
) Error!void {
    if (pushed_vregs.items.len < 2) return Error.AllocationMissing;
    const rhs_v = pushed_vregs.pop().?;
    const lhs_v = pushed_vregs.pop().?;
    const result_v = next_vreg.*;
    next_vreg.* += 1;
    if (result_v >= alloc.slots.len) return Error.SlotOverflow;

    const rhs_x = try gpr.resolveXmm(alloc, rhs_v);
    const lhs_x = try gpr.resolveXmm(alloc, lhs_v);
    const dst_x = try gpr.resolveXmm(alloc, result_v);

    if (dst_x != lhs_x) {
        try buf.appendSlice(allocator, inst.encMovapsXmmXmm(dst_x, lhs_x).slice());
    }
    try buf.appendSlice(allocator, inst.encPaddD(dst_x, rhs_x).slice());
    try pushed_vregs.append(allocator, result_v);
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "emitI32x4Add: three fresh XMM slots — MOVAPS xmm10, xmm8 + PADDD xmm10, xmm9" {
    // Synthetic regalloc state: 3 v128 vregs at slot ids 0/1/2 →
    // XMM8/XMM9/XMM10 via abi.fpSlotToReg. Push lhs (vreg 0) +
    // rhs (vreg 1); the handler allocates result (vreg 2).
    var slot_ids = [_]u16{ 0, 1, 2 };
    const alloc: regalloc.Allocation = .{
        .slots = &slot_ids,
        .n_slots = 3,
        .max_reg_slots_gpr = 4,
        .max_reg_slots_fp = 6,
    };

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    var pushed: std.ArrayList(u32) = .empty;
    defer pushed.deinit(testing.allocator);
    try pushed.append(testing.allocator, 0);
    try pushed.append(testing.allocator, 1);
    var next_vreg: u32 = 2;

    try emitI32x4Add(testing.allocator, &buf, alloc, &pushed, &next_vreg);

    // Expected:
    //   MOVAPS xmm10, xmm8   = 45 0F 28 D0  (REX = 0x40|R|B = 0x45)
    //   PADDD  xmm10, xmm9   = 66 45 0F FE D1
    var expected_buf: [32]u8 = undefined;
    var n: usize = 0;
    const mov = inst.encMovapsXmmXmm(.xmm10, .xmm8);
    @memcpy(expected_buf[n..][0..mov.slice().len], mov.slice());
    n += mov.slice().len;
    const padd = inst.encPaddD(.xmm10, .xmm9);
    @memcpy(expected_buf[n..][0..padd.slice().len], padd.slice());
    n += padd.slice().len;
    try testing.expectEqualSlices(u8, expected_buf[0..n], buf.items);
    try testing.expectEqual(@as(usize, 1), pushed.items.len);
    try testing.expectEqual(@as(u32, 2), pushed.items[0]);
    try testing.expectEqual(@as(u32, 3), next_vreg);
}

test "emitI32x4Add: dst aliases lhs slot — MOVAPS elided, only PADDD emitted" {
    // Force dst onto the same physical XMM as lhs by giving
    // them the same slot id (the regalloc would do this via the
    // free-pool LIFO when lhs's last use is the binop). The
    // handler should detect dst_x == lhs_x and skip the MOVAPS.
    var slot_ids = [_]u16{ 0, 1, 0 };
    const alloc: regalloc.Allocation = .{
        .slots = &slot_ids,
        .n_slots = 2,
        .max_reg_slots_gpr = 4,
        .max_reg_slots_fp = 6,
    };

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    var pushed: std.ArrayList(u32) = .empty;
    defer pushed.deinit(testing.allocator);
    try pushed.append(testing.allocator, 0);
    try pushed.append(testing.allocator, 1);
    var next_vreg: u32 = 2;

    try emitI32x4Add(testing.allocator, &buf, alloc, &pushed, &next_vreg);

    try testing.expectEqualSlices(u8, inst.encPaddD(.xmm8, .xmm9).slice(), buf.items);
}

test "emitI32x4Add: spilled rhs surfaces UnsupportedOp (16-byte spill defers to 9.7-c)" {
    // Slot id 6 is past max_reg_slots_fp = 6; alloc.slot(.fpr)
    // returns .spill, and resolveXmm rejects spilled FP vregs
    // with Error.UnsupportedOp because xmmLoadSpilled's MOVSD
    // path is 8-byte (truncates the upper 64 bits of a v128).
    // 16-byte MOVDQU spill helpers are the 9.7-c lift.
    var slot_ids = [_]u16{ 0, 6, 1 };
    const alloc: regalloc.Allocation = .{
        .slots = &slot_ids,
        .n_slots = 7,
        .max_reg_slots_gpr = 4,
        .max_reg_slots_fp = 6,
    };

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    var pushed: std.ArrayList(u32) = .empty;
    defer pushed.deinit(testing.allocator);
    try pushed.append(testing.allocator, 0);
    try pushed.append(testing.allocator, 1);
    var next_vreg: u32 = 2;

    try testing.expectError(Error.UnsupportedOp, emitI32x4Add(testing.allocator, &buf, alloc, &pushed, &next_vreg));
}
