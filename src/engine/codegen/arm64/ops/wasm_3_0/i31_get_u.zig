//! arm64 emit handler for `i31.get_u` — Wasm 3.0 GC §3.3.14.
//! Pop a (ref null i31); trap if null, else push the unsigned i32
//! `(payload >> 1) & 0x7FFFFFFF`. The W-form logical shift right
//! by 1 already zeroes bit 31, so LSR alone realises the mask
//! (matches the interp handler in `wasm_3_0/i31_ops.zig`).
//! Non-allocating.
//!
//! Lowering: TST Wn, #1; B.EQ → null_reference stub (null_ref_fixups →
//! code 10; D-293 slice-4e) for null / non-i31; else LSR Wd, Wn, #1. Arm IHI
//! 0055 §C6.2.15 (TST) + §C6.2.179 (LSR immediate).

const meta = @import("../../../../../instruction/wasm_3_0/i31_get_u.zig");
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
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encTstImm1W(wn));
    const fixup_at: u32 = @intCast(ctx.buf.items.len);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encBCond(.eq, 0));
    try ctx.null_ref_fixups.append(ctx.allocator, fixup_at); // D-293 slice-4e null_reference (code 10)
    const wd = try gpr.gprDefSpilled(ctx.alloc, args.result, 0);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLsrImmW(wd, wn, 1));
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, args.result);
}
