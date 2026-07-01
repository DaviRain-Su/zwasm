//! arm64 emit handler for `ref.i31` — Wasm 3.0 GC §3.3.14.
//! Pop an i32, push a (ref i31): the i31-packed value
//! `(x << 1) | 1` (low-bit-1 discriminant per ADR-0116 D4). Spec
//! `ref.i31` silently truncates wider-than-31-bit inputs; the
//! `<< 1` discards bit 31, mirroring `feature/gc/i31.zig`
//! `i32ToI31Truncate` (the interp handler). Non-allocating — no
//! heap, no runtime trampoline, no type-info.
//!
//! Lowering: ADD Wd, Wn, Wn (= x << 1) then ORR Wd, Wd, #1
//! (set the discriminant). anyref lives in a GPR as a u32, so the
//! W-form (implicitly zero-extending bits 63:32) is correct.
//! Arm IHI 0055 §C6.2.4 (ADD) + §C6.2.181 (ORR immediate).

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
    const wn = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.src, 0);
    const wd = try gpr.gprDefSpilled(ctx.alloc, args.result, 0);
    // (x << 1) via self-add, then set the low-bit-1 i31 tag.
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encAddRegW(wd, wn, wn));
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encOrrImm1W(wd, wd));
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, args.result);
}
