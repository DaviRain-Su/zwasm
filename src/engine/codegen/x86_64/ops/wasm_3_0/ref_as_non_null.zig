//! x86_64 emit handler for `ref.as_non_null` — Wasm 3.0 function-
//! references §3.3.8.5. Pop a ref, trap (NullReference) if it's the
//! null sentinel (0), else leave it on the stack (identity).
//!
//! Implementation: pop src vreg, load into R, `TEST R, R`, `JE rel32`
//! placeholder → bounds_fixups (generic trap stub at function
//! epilogue; the entry path maps `trap_flag != 0` to generic
//! `Error.Trap` — see entry.zig:173/188 + ADR-0123 D2). Identity
//! passthrough: push src vreg back (no new result vreg, no MOV).
//! Mirrors the div-by-zero null-check pattern at
//! `op_alu_int.zig:799-803`.

const meta = @import("../../../../../instruction/wasm_3_0/ref_as_non_null.zig");
const ctx_mod = @import("../../ctx.zig");
const gpr = @import("../../gpr.zig");
const inst = @import("../../inst.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, _: *const zir.ZirInstr) ctx_mod.Error!void {
    if (ctx.pushed_vregs.items.len < 1) return ctx_mod.Error.AllocationMissing;
    const src = ctx.pushed_vregs.pop().?;
    const rn = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, src, 0);
    try ctx.buf.appendSlice(ctx.allocator, inst.encTestRR(.q, rn, rn).slice());
    const fixup_at: u32 = @intCast(ctx.buf.items.len);
    try ctx.buf.appendSlice(ctx.allocator, inst.encJccRel32(.e, 0).slice());
    try ctx.null_ref_fixups.append(ctx.allocator, fixup_at); // D-293 slice-4b null_reference (code 10)
    // Identity: push src back; src's storage holds the funcref unchanged.
    try ctx.pushed_vregs.append(ctx.allocator, src);
}
