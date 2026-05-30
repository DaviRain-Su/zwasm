//! arm64 emit handler for `i31.get_s` — Wasm 3.0 GC §3.3.14.
//! Pop a (ref null i31); trap if null, else push the
//! sign-extended i32 `payload >> 1` (arithmetic). Matches the
//! interp handler (`instruction/wasm_3_0/i31_ops.zig`): the
//! low-bit-1 discriminant means null (ref == 0) and any non-i31
//! both fail `isI31Ref` and trap. Non-allocating.
//!
//! Lowering: TST Wn, #1 (Z set when bit 0 clear → null/non-i31);
//! B.EQ → generic trap stub (bounds_fixups, ADR-0123 D2). Else
//! ASR Wd, Wn, #1 (sign-replicating). Arm IHI 0055 §C6.2.15 (TST)
//! + §C6.2.13 (ASR immediate).

const meta = @import("../../../../../instruction/wasm_3_0/i31_get_s.zig");
const ctx_mod = @import("../../ctx.zig");
const gpr = @import("../../gpr.zig");
const inst = @import("../../inst.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, _: *const zir.ZirInstr) ctx_mod.Error!void {
    const args = try ctx.popUnary();
    const wn = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.src, 0);
    // Null / non-i31 trap: read bit 0 of the discriminant before
    // the shift overwrites the dest reg (which may alias wn).
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encTstImm1W(wn));
    const fixup_at: u32 = @intCast(ctx.buf.items.len);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encBCond(.eq, 0));
    try ctx.bounds_fixups.append(ctx.allocator, fixup_at);
    const wd = try gpr.gprDefSpilled(ctx.alloc, args.result, 0);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encAsrImmW(wd, wn, 1));
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, args.result);
}
