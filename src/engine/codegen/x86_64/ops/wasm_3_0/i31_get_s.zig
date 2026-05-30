//! x86_64 emit handler for `i31.get_s` — Wasm 3.0 GC §3.3.14.
//! Mirror of the arm64 handler: pop a (ref null i31); trap if null
//! / non-i31, else push the sign-extended i32 `payload >> 1`
//! (arithmetic). The low-bit-1 discriminant means null (ref == 0)
//! and any non-i31 both fail the bit-0 test. Non-allocating.
//!
//! Lowering: TEST src, 1 (ZF set when bit 0 clear); JE rel32 →
//! generic trap stub (bounds_fixups, ADR-0123 D2; mirrors
//! ref_as_non_null). Else MOV dst, src (skip if same reg);
//! SAR dst, 1 (sign-replicating). Intel SDM Vol.2 (TEST 0xF7 /0,
//! SAR 0xC1 /7).

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
    const src_r = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.src, 0);
    // Read bit 0 before any write to dst (which may alias src).
    try ctx.buf.appendSlice(ctx.allocator, inst.encTestRImm32(.d, src_r, 1).slice());
    const fixup_at: u32 = @intCast(ctx.buf.items.len);
    try ctx.buf.appendSlice(ctx.allocator, inst.encJccRel32(.e, 0).slice());
    try ctx.bounds_fixups.append(ctx.allocator, fixup_at);
    const dst_r = try gpr.gprDefSpilled(ctx.alloc, args.result, 0);
    if (dst_r != src_r) try ctx.buf.appendSlice(ctx.allocator, inst.encMovRR(.d, dst_r, src_r).slice());
    try ctx.buf.appendSlice(ctx.allocator, inst.encSarRImm8(.d, dst_r, 1).slice());
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, args.result);
}
