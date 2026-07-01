//! x86_64 emit handler for `ref.i31` — Wasm 3.0 GC §3.3.14.
//! Mirror of the arm64 handler: pop i32, push the i31-packed value
//! `(x << 1) | 1` (low-bit-1 discriminant per ADR-0116 D4). Spec
//! `ref.i31` silently truncates wider-than-31-bit inputs; the
//! `<< 1` discards bit 31. Non-allocating (no heap / trampoline).
//!
//! Lowering: MOV dst, src (skip if same reg); ADD dst, dst (= x<<1);
//! OR dst, 1. The .d (32-bit) form zero-extends to 64 bits, correct
//! for anyref-as-u32. Intel SDM Vol.2 (ADD 0x01 / OR 0x83 /1).

const meta = @import("../../../../../instruction/wasm_3_0/ref_i31.zig");
const ctx_mod = @import("../../ctx.zig");
const gpr = @import("../../gpr.zig");
const inst = @import("../../inst.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, _: *const zir.ZirInstr) ctx_mod.Error!void {
    const args = try ctx.popUnary();
    const src_r = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.src, 0);
    const dst_r = try gpr.gprDefSpilled(ctx.alloc, args.result, 0);
    if (dst_r != src_r) try ctx.buf.appendSlice(ctx.allocator, inst.encMovRR(.d, dst_r, src_r).slice());
    try ctx.buf.appendSlice(ctx.allocator, inst.encAddRR(.d, dst_r, dst_r).slice());
    try ctx.buf.appendSlice(ctx.allocator, inst.encOrRImm8(.d, dst_r, 1).slice());
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, args.result);
}
