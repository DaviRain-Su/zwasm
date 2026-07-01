//! arm64 emit handler for `ref.eq` — Wasm 3.0 GC §3.3.5.2.
//! Pop two eqref operands, push i32 (1 iff same reference identity, else 0;
//! two nulls compare equal per spec). GcRefs, i31 tagged values, and null
//! (0) are all stored zero-extended in the 8-byte operand slots, so a
//! 64-bit register compare matches the interp's u64 `.ref` compare for
//! every eqref case. Non-allocating — no heap, no trampoline, no runtime
//! pointer.
//!
//! Lowering: CMP Xa, Xb ; CSET Wd, EQ. Arm IHI 0055 §C6.2.65 (SUBS/CMP
//! shifted-reg) + §C6.2.71 (CSET = CSINC WZR,WZR alias).
//!
//! `ref.eq`'s interp + lower + validate live in the multi-op
//! `instruction/wasm_3_0/ref_convert_ops.zig` (no per-op meta file), so the
//! op_tag / level metadata is declared here directly.

const ctx_mod = @import("../../ctx.zig");
const gpr = @import("../../gpr.zig");
const inst = @import("../../inst.zig");
const zir = @import("../../../../../ir/zir.zig");
const collector = @import("../../../../../ir/dispatch_collector.zig");

pub const op_tag: zir.ZirOp = .@"ref.eq";
pub const wasm_level: ?collector.WasmLevel = .v3_0;
pub const wasi_level: ?collector.WasiLevel = null;

pub fn emit(ctx: *ctx_mod.EmitCtx, _: *const zir.ZirInstr) ctx_mod.Error!void {
    // args.lhs = a (deeper), args.rhs = b (top), args.result = i32.
    const args = try ctx.popBinary();
    const xa = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.lhs, 0);
    const xb = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.rhs, 1);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encCmpRegX(xa, xb));
    const rd = try gpr.gprDefSpilled(ctx.alloc, args.result, 0);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encCsetW(rd, .eq));
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, args.result);
}
