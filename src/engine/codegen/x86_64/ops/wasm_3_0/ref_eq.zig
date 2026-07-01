//! x86_64 emit handler for `ref.eq` — Wasm 3.0 GC §3.3.5.2.
//! Mirror of the arm64 handler: pop two eqref operands, compare the
//! (zero-extended) ref values, push i32 (1=same / 0=distinct; two nulls
//! equal). Non-allocating — no heap, no trampoline.
//!
//! Lowering: CMP Ra, Rb (64-bit) ; SETE dst8 ; MOVZX dst32, dst8 — the same
//! compare→i32 idiom as `i32.eq` (op_alu_int emitI32Compare). Intel SDM
//! Vol.2 (CMP 0x39, SETcc 0x0F 0x94, MOVZX 0x0F 0xB6).
//!
//! `ref.eq`'s interp + lower + validate live in the multi-op
//! `instruction/wasm_3_0/ref_convert_ops.zig`, so op_tag / level metadata is
//! declared here directly.

const ctx_mod = @import("../../ctx.zig");
const gpr = @import("../../gpr.zig");
const inst = @import("../../inst.zig");
const zir = @import("../../../../../ir/zir.zig");
const collector = @import("../../../../../ir/dispatch_collector.zig");

pub const op_tag: zir.ZirOp = .@"ref.eq";
pub const wasm_level: ?collector.WasmLevel = .v3_0;
pub const wasi_level: ?collector.WasiLevel = null;

pub fn emit(ctx: *ctx_mod.EmitCtx, _: *const zir.ZirInstr) ctx_mod.Error!void {
    const args = try ctx.popBinary(); // lhs=a, rhs=b, result=i32
    const xa = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.lhs, 0);
    const xb = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.rhs, 1);
    try ctx.buf.appendSlice(ctx.allocator, inst.encCmpRR(.q, xa, xb).slice());
    const rd = try gpr.gprDefSpilled(ctx.alloc, args.result, 0);
    try ctx.buf.appendSlice(ctx.allocator, inst.encSetccR(.e, rd).slice());
    try ctx.buf.appendSlice(ctx.allocator, inst.encMovzxR32R8(rd, rd).slice());
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, args.result);
}
