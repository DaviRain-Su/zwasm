//! x86_64 emit handler for `i31.get_u` — Wasm 3.0 GC §3.3.14.
//! Mirror of the arm64 handler: pop a (ref null i31); trap if null
//! / non-i31, else push the unsigned i32 `(payload >> 1) &
//! 0x7FFFFFFF`. The .d (32-bit) logical SHR by 1 already zeroes
//! bit 31, so SHR alone realises the mask. Non-allocating.
//!
//! Lowering: TEST src, 1; JE rel32 → null_reference stub
//! (null_ref_fixups → code 10; D-293 slice-4e). Else MOV dst, src (skip
//! if same reg); SHR dst, 1. Intel SDM Vol.2 (TEST 0xF7 /0, SHR 0xC1 /5).

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
    const src_r = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.src, 0);
    try ctx.buf.appendSlice(ctx.allocator, inst.encTestRImm32(.d, src_r, 1).slice());
    const fixup_at: u32 = @intCast(ctx.buf.items.len);
    try ctx.buf.appendSlice(ctx.allocator, inst.encJccRel32(.e, 0).slice());
    try ctx.null_ref_fixups.append(ctx.allocator, fixup_at); // D-293 slice-4e null_reference (code 10)
    const dst_r = try gpr.gprDefSpilled(ctx.alloc, args.result, 0);
    if (dst_r != src_r) try ctx.buf.appendSlice(ctx.allocator, inst.encMovRR(.d, dst_r, src_r).slice());
    try ctx.buf.appendSlice(ctx.allocator, inst.encShrRImm8(.d, dst_r, 1).slice());
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, args.result);
}
