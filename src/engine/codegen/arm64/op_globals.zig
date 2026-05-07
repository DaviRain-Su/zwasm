//! ARM64 emit pass — `global.get` / `global.set` handlers.
//!
//! Per ADR-0027: each global is one `runtime.value.Value` (8 bytes)
//! at byte offset `idx * 8` within `[X23 = globals_base_save_gpr]`.
//! X23 is pre-loaded from `[X19 + globals_base_off]` at the function
//! prologue when the function actually touches a global op (prescan-
//! driven; functions without globals skip the X23 load).
//!
//! i32 globals access the low 4 bytes of the 8-byte slot via
//! W-form LDR / STR. i64 / f32 / f64 globals are out of scope for
//! this chunk (M3-a-1 ships i32 globals only; widening lands as a
//! separate chunk paired with i64 / FP infrastructure).
//!
//! Zone 2 (`src/engine/codegen/arm64/`).

const std = @import("std");

const zir = @import("../../../ir/zir.zig");
const inst = @import("inst.zig");
const ctx_mod = @import("ctx.zig");
const gpr = @import("gpr.zig");
const abi = @import("abi.zig");

const ZirInstr = zir.ZirInstr;
const EmitCtx = ctx_mod.EmitCtx;
const Error = ctx_mod.Error;

/// `global.get N` — push a vreg, load `[X23 + N*8]` (W-form for
/// i32) into the assigned reg.
///
/// Caller MUST have ensured `uses_globals` was true at prologue
/// time; otherwise X23 is undefined.
pub fn emitI32GlobalGet(ctx: *EmitCtx, ins: *const ZirInstr) Error!void {
    const idx = ins.payload;
    // imm12 in W-form scales by 4 → max byte_offset = 4 * 4095 = 16380
    // → max idx = 16380 / 8 = 2047. Beyond that, escalate (very rare).
    const byte_off: u32 = idx * 8;
    if (byte_off > 16380) {
        std.debug.print("arm64/op_globals: global.get SlotOverflow func[{d}] idx={d} byte_off={d}>16380\n", .{ ctx.func.func_idx, idx, byte_off });
        return Error.SlotOverflow;
    }

    const result = ctx.next_vreg.*;
    ctx.next_vreg.* += 1;
    if (result >= ctx.alloc.slots.len) {
        std.debug.print("arm64/op_globals: global.get SlotOverflow func[{d}] vreg={d} >= slots.len={d}\n", .{ ctx.func.func_idx, result, ctx.alloc.slots.len });
        return Error.SlotOverflow;
    }
    const wd = try gpr.gprDefSpilled(ctx.alloc, result, 0);

    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrImmW(wd, abi.globals_base_save_gpr, @intCast(byte_off)));
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, result);
}

/// `global.set N` — pop a vreg, store its W (low 32 bits) into
/// `[X23 + N*8]` (i32 globals only; the upper 32 bits of the
/// 8-byte slot are left untouched, which is fine for i32-typed
/// globals because the slot was zero-initialised at module load).
pub fn emitI32GlobalSet(ctx: *EmitCtx, ins: *const ZirInstr) Error!void {
    const idx = ins.payload;
    const byte_off: u32 = idx * 8;
    if (byte_off > 16380) {
        std.debug.print("arm64/op_globals: global.set SlotOverflow func[{d}] idx={d} byte_off={d}>16380\n", .{ ctx.func.func_idx, idx, byte_off });
        return Error.SlotOverflow;
    }

    if (ctx.pushed_vregs.items.len < 1) return Error.AllocationMissing;
    const src_v = ctx.pushed_vregs.pop().?;
    const ws = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, src_v, 0);

    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encStrImmW(ws, abi.globals_base_save_gpr, @intCast(byte_off)));
}
