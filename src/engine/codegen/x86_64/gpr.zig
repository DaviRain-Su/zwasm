//! x86_64 emit pass — GPR / XMM resolution + spill staging
//! helpers shared across every op-handler module.
//!
//! Mirror of `arm64/gpr.zig` (per ADR-0023 §3 + ADR-0021 sub-
//! deliverable b) — extracted so op_const / op_alu / op_memory /
//! etc. can reach for these helpers without importing emit.zig.
//!
//! - `writeBytes` — append an x86_64-encoded instruction's bytes
//!   (`EncodedInsn` from `inst.zig`) to the buffer.
//! - `resolveGpr` — vreg → physical Gpr (declines spilled vregs;
//!   the bare-resolution shape used by handlers that haven't been
//!   migrated to spill-aware emission).
//! - `gprLoadSpilled` — spill-aware operand load via stage reg.
//! - `gprDefSpilled` — spill-aware result def via stage reg.
//! - `gprStoreSpilled` — pair of `gprDefSpilled`; flushes stage
//!   reg to spill slot.
//! - `resolveXmm` — XMM-class counterpart of `resolveGpr`.
//! - `xmmLoadSpilled` / `xmmDefSpilled` / `xmmStoreSpilled` —
//!   XMM-class spill-staging trio (mirrors `fpLoadSpilled` etc.
//!   in arm64; uses `abi.fp_spill_stage_xmms` (XMM14/XMM15) and
//!   the F64 spill encoders for class-uniform 8-byte stride).
//!
//! **Spill frame addressing**: x86_64 places locals + spills
//! BELOW RBP (frame grows down). `spill_base_off` is the byte
//! distance from RBP to the start of the spill area; the load /
//! store encoder takes `disp = -(spill_base_off + spill_off)` as
//! a signed i8. With disp8 (-128..127), the spill frame supports
//! up to 16 slots (8-byte stride). disp32 fallback lands in a
//! follow-up chunk if a fixture exceeds disp8 range.
//!
//! Zone 2 (`src/engine/codegen/x86_64/`) — must NOT import
//! `src/engine/codegen/arm64/` per ROADMAP §A3.

const std = @import("std");

const inst = @import("inst.zig");
const abi = @import("abi.zig");
const regalloc = @import("../shared/regalloc.zig");
const types = @import("types.zig");

const Allocator = std.mem.Allocator;
const Error = types.Error;
const Gpr = abi.Gpr;
const Xmm = abi.Xmm;

/// Append `enc.bytes[0..enc.len]` to `buf`. Mirrors arm64's
/// `writeU32` but x86_64 instructions are variable-length, so
/// the encoder returns a length-prefixed array (`EncodedInsn`).
pub fn writeBytes(allocator: Allocator, buf: *std.ArrayList(u8), enc: inst.EncodedInsn) !void {
    try buf.appendSlice(allocator, enc.bytes[0..enc.len]);
}

/// Convert a u32 RBP-relative spill distance into the i8 disp
/// the encoders require. Returns `Error.SlotOverflow` when the
/// distance exceeds disp8 range (chunk 13b adds disp32 fallback).
fn rbpDispNegI8(spill_base_off: u32, spill_off: u32) Error!i8 {
    const abs = spill_base_off + spill_off;
    if (abs == 0 or abs > 128 or (abs & 7) != 0) return Error.SlotOverflow;
    return @intCast(-@as(i32, @intCast(abs)));
}

/// Resolve a vreg's home register (GPR class). Returns the
/// allocated reg or `Error.UnsupportedOp` for spilled vregs
/// (handlers that haven't been migrated to spill-aware emission).
pub fn resolveGpr(alloc: regalloc.Allocation, vreg: usize) Error!Gpr {
    return switch (alloc.slot(vreg, .gpr)) {
        .reg => |id| abi.slotToReg(id) orelse Error.SlotOverflow,
        .spill => blk: {
            std.debug.print(
                "x86_64/gpr: resolveGpr rejected spilled vreg={d} (handler not spill-aware)\n",
                .{vreg},
            );
            break :blk Error.UnsupportedOp;
        },
    };
}

/// Resolve a vreg's home for **op operand load**. If the vreg
/// is in a register, returns that reg directly. If spilled,
/// emits `MOV r64, [RBP - (spill_base_off + spill_off)]` staging
/// through `abi.spill_stage_gprs[stage_idx]` (R10/R11) and
/// returns the stage reg.
///
/// `stage_idx` selects which stage reg (0=R10, 1=R11). Use 0 for
/// the first/only operand, 1 for the second operand of a binary
/// op (so two spilled operands don't collide).
pub fn gprLoadSpilled(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    spill_base_off: u32,
    vreg: usize,
    stage_idx: u8,
) Error!Gpr {
    return switch (alloc.slot(vreg, .gpr)) {
        .reg => |id| abi.slotToReg(id) orelse Error.SlotOverflow,
        .spill => |off| blk: {
            const stage = abi.spill_stage_gprs[stage_idx];
            const disp = try rbpDispNegI8(spill_base_off, off);
            try writeBytes(allocator, buf, inst.encLoadR64MemRBP(stage, disp));
            break :blk stage;
        },
    };
}

/// Resolve a vreg's home for **op result def**. If the vreg is
/// in a register, returns that reg directly. If spilled, returns
/// the stage reg (caller encodes the op writing into it; then
/// calls `gprStoreSpilled` to flush to the spill slot).
pub fn gprDefSpilled(
    alloc: regalloc.Allocation,
    vreg: usize,
    stage_idx: u8,
) Error!Gpr {
    return switch (alloc.slot(vreg, .gpr)) {
        .reg => |id| abi.slotToReg(id) orelse Error.SlotOverflow,
        .spill => abi.spill_stage_gprs[stage_idx],
    };
}

/// Pair of `gprDefSpilled`. After encoding the op (which wrote
/// the result into the stage reg), emits `MOV [RBP - (spill_base_
/// off + spill_off)], r64`. No-op for vregs in registers.
pub fn gprStoreSpilled(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    spill_base_off: u32,
    vreg: usize,
    stage_idx: u8,
) Error!void {
    switch (alloc.slot(vreg, .gpr)) {
        .reg => {},
        .spill => |off| {
            const stage = abi.spill_stage_gprs[stage_idx];
            const disp = try rbpDispNegI8(spill_base_off, off);
            try writeBytes(allocator, buf, inst.encStoreR64MemRBP(disp, stage));
        },
    }
}

/// XMM-class counterpart of `resolveGpr`. Consults the class-
/// aware `Allocation.slot(vreg, .fpr)` API (D-036): the FP
/// boundary `max_reg_slots_fp` (default 8, matching
/// `abi.allocatable_xmms.len`) decides reg-vs-spill, distinct
/// from the GPR boundary.
pub fn resolveXmm(alloc: regalloc.Allocation, vreg: usize) Error!Xmm {
    return switch (alloc.slot(vreg, .fpr)) {
        .reg => |id| abi.fpSlotToReg(id) orelse Error.SlotOverflow,
        .spill => |off| blk: {
            std.debug.print(
                "x86_64/gpr: resolveXmm rejected spilled vreg={d} spill_off={d} (handler not XMM-spill-aware)\n",
                .{ vreg, off },
            );
            break :blk Error.UnsupportedOp;
        },
    };
}

/// XMM-class counterpart of `gprLoadSpilled`. If the FP vreg is
/// in an XMM register, returns that reg directly. If spilled,
/// emits `MOVSD xmm, [RBP - (spill_base_off + spill_off)]`
/// staging through `abi.fp_spill_stage_xmms[stage_idx]`
/// (XMM14/XMM15) and returns the stage reg.
///
/// MOVSD (F64 form) is used uniformly so the spill stride matches
/// the GPR (8-byte) stride — a spilled f32 vreg writes 64 bits
/// with the upper 32 bits unspecified, but the load reads the
/// same 64 bits and SS-form ops on the resulting XMM ignore the
/// upper 32 bits.
pub fn xmmLoadSpilled(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    spill_base_off: u32,
    vreg: usize,
    stage_idx: u8,
) Error!Xmm {
    return switch (alloc.slot(vreg, .fpr)) {
        .reg => |id| abi.fpSlotToReg(id) orelse Error.SlotOverflow,
        .spill => |off| blk: {
            const stage = abi.fp_spill_stage_xmms[stage_idx];
            const disp = try rbpDispNegI8(spill_base_off, off);
            try writeBytes(allocator, buf, inst.encLoadXmmF64MemRBP(stage, disp));
            break :blk stage;
        },
    };
}

/// XMM-class counterpart of `gprDefSpilled`.
pub fn xmmDefSpilled(
    alloc: regalloc.Allocation,
    vreg: usize,
    stage_idx: u8,
) Error!Xmm {
    return switch (alloc.slot(vreg, .fpr)) {
        .reg => |id| abi.fpSlotToReg(id) orelse Error.SlotOverflow,
        .spill => abi.fp_spill_stage_xmms[stage_idx],
    };
}

/// Pair of `xmmDefSpilled`. Emits `MOVSD [RBP - (spill_base_off
/// + spill_off)], xmm` from the stage reg. No-op for in-XMM-reg
/// vregs.
pub fn xmmStoreSpilled(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    spill_base_off: u32,
    vreg: usize,
    stage_idx: u8,
) Error!void {
    switch (alloc.slot(vreg, .fpr)) {
        .reg => {},
        .spill => |off| {
            const stage = abi.fp_spill_stage_xmms[stage_idx];
            const disp = try rbpDispNegI8(spill_base_off, off);
            try writeBytes(allocator, buf, inst.encStoreXmmF64MemRBP(disp, stage));
        },
    }
}

// ============================================================
// Tests — D-045 chunk 13a foundation
// ============================================================

const testing = std.testing;

test "rbpDispNegI8: spill_base_off=8 + off=0 → disp=-8" {
    const disp = try rbpDispNegI8(8, 0);
    try testing.expectEqual(@as(i8, -8), disp);
}

test "rbpDispNegI8: spill_base_off=64 + off=8 → disp=-72" {
    const disp = try rbpDispNegI8(64, 8);
    try testing.expectEqual(@as(i8, -72), disp);
}

test "rbpDispNegI8: spill_base_off=120 + off=8 = 128 → disp=-128 (boundary)" {
    const disp = try rbpDispNegI8(120, 8);
    try testing.expectEqual(@as(i8, -128), disp);
}

test "rbpDispNegI8: abs > 128 → SlotOverflow" {
    try testing.expectError(Error.SlotOverflow, rbpDispNegI8(128, 8));
}

test "rbpDispNegI8: misaligned (not 8-multiple) → SlotOverflow" {
    try testing.expectError(Error.SlotOverflow, rbpDispNegI8(8, 4));
}

test "rbpDispNegI8: zero distance (no spill area) → SlotOverflow" {
    try testing.expectError(Error.SlotOverflow, rbpDispNegI8(0, 0));
}

test "gprLoadSpilled: vreg in reg returns slotToReg without emitting bytes" {
    const slots = [_]u8{0};
    const alloc: regalloc.Allocation = .{ .slots = &slots, .n_slots = 1 };
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    const r = try gprLoadSpilled(testing.allocator, &buf, alloc, 8, 0, 0);
    try testing.expectEqual(abi.allocatable_gprs[0], r);
    try testing.expectEqual(@as(usize, 0), buf.items.len);
}

test "gprLoadSpilled: spilled vreg emits MOV r10, [rbp+disp] (stage_idx=0)" {
    const pool_len: u8 = abi.allocatable_gprs.len;
    const slots = [_]u8{pool_len};
    const alloc: regalloc.Allocation = .{
        .slots = &slots,
        .n_slots = pool_len + 1,
        .max_reg_slots_gpr = pool_len,
    };
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    const r = try gprLoadSpilled(testing.allocator, &buf, alloc, 8, 0, 0);
    try testing.expectEqual(Gpr.r10, r);
    const expected = inst.encLoadR64MemRBP(.r10, -8);
    try testing.expectEqual(@as(usize, expected.len), buf.items.len);
    try testing.expectEqualSlices(u8, expected.bytes[0..expected.len], buf.items);
}

test "gprLoadSpilled: stage_idx=1 yields R11" {
    const pool_len: u8 = abi.allocatable_gprs.len;
    const slots = [_]u8{pool_len};
    const alloc: regalloc.Allocation = .{
        .slots = &slots,
        .n_slots = pool_len + 1,
        .max_reg_slots_gpr = pool_len,
    };
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    const r = try gprLoadSpilled(testing.allocator, &buf, alloc, 8, 0, 1);
    try testing.expectEqual(Gpr.r11, r);
}

test "gprStoreSpilled: spilled vreg emits MOV [rbp+disp], r10" {
    const pool_len: u8 = abi.allocatable_gprs.len;
    const slots = [_]u8{pool_len};
    const alloc: regalloc.Allocation = .{
        .slots = &slots,
        .n_slots = pool_len + 1,
        .max_reg_slots_gpr = pool_len,
    };
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    try gprStoreSpilled(testing.allocator, &buf, alloc, 8, 0, 0);
    const expected = inst.encStoreR64MemRBP(-8, .r10);
    try testing.expectEqual(@as(usize, expected.len), buf.items.len);
    try testing.expectEqualSlices(u8, expected.bytes[0..expected.len], buf.items);
}

test "gprStoreSpilled: in-reg vreg emits no bytes" {
    const slots = [_]u8{2};
    const alloc: regalloc.Allocation = .{ .slots = &slots, .n_slots = 3 };
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    try gprStoreSpilled(testing.allocator, &buf, alloc, 8, 0, 0);
    try testing.expectEqual(@as(usize, 0), buf.items.len);
}

test "gprDefSpilled: in-reg vreg returns home; spilled returns stage" {
    const pool_len: u8 = abi.allocatable_gprs.len;
    const slots = [_]u8{ 3, pool_len };
    const alloc: regalloc.Allocation = .{
        .slots = &slots,
        .n_slots = pool_len + 1,
        .max_reg_slots_gpr = pool_len,
    };
    try testing.expectEqual(abi.allocatable_gprs[3], try gprDefSpilled(alloc, 0, 0));
    try testing.expectEqual(Gpr.r10, try gprDefSpilled(alloc, 1, 0));
    try testing.expectEqual(Gpr.r11, try gprDefSpilled(alloc, 1, 1));
}

test "xmmLoadSpilled: spilled vreg emits MOVSD xmm14, [rbp+disp]" {
    const pool_len: u8 = abi.allocatable_xmms.len;
    const slots = [_]u8{pool_len};
    const alloc: regalloc.Allocation = .{
        .slots = &slots,
        .n_slots = pool_len + 1,
        .max_reg_slots_fp = pool_len,
    };
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    const r = try xmmLoadSpilled(testing.allocator, &buf, alloc, 8, 0, 0);
    try testing.expectEqual(Xmm.xmm14, r);
    const expected = inst.encLoadXmmF64MemRBP(.xmm14, -8);
    try testing.expectEqual(@as(usize, expected.len), buf.items.len);
    try testing.expectEqualSlices(u8, expected.bytes[0..expected.len], buf.items);
}

test "xmmStoreSpilled: spilled vreg emits MOVSD [rbp+disp], xmm14" {
    const pool_len: u8 = abi.allocatable_xmms.len;
    const slots = [_]u8{pool_len};
    const alloc: regalloc.Allocation = .{
        .slots = &slots,
        .n_slots = pool_len + 1,
        .max_reg_slots_fp = pool_len,
    };
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(testing.allocator);
    try xmmStoreSpilled(testing.allocator, &buf, alloc, 8, 0, 0);
    const expected = inst.encStoreXmmF64MemRBP(-8, .xmm14);
    try testing.expectEqual(@as(usize, expected.len), buf.items.len);
    try testing.expectEqualSlices(u8, expected.bytes[0..expected.len], buf.items);
}
