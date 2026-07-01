//! arm64 emit handler for `i64.div_u` — Zone 2 per ADR-0074.
//! Delegates to op_alu_int.emitI64DivRem.
//!
//! Note: x86_64 counterpart deferred to a later chunk that widens
//! the x86_64 dispatcher tuple to include `bounds_fixups` (the
//! 8th arg emitI32DivRem / emitI64DivRem require for trap fixup
//! recording on x86_64). x86_64 div/rem stays in legacy switch
//! until that wire amendment lands.

const meta = @import("../../../../../instruction/wasm_1_0/i64_div_u.zig");
const ctx_mod = @import("../../ctx.zig");
const op_alu_int = @import("../../op_alu_int.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    return op_alu_int.emitI64DivRem(ctx, ins);
}
