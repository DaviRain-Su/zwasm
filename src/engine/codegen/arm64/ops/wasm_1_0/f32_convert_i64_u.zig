//! arm64 emit handler for `f32.convert_i64_u` — Zone 2 per ADR-0074.
//! Delegates to op_convert.emitConvertIntToFloat.

const meta = @import("../../../../../instruction/wasm_1_0/f32_convert_i64_u.zig");
const ctx_mod = @import("../../ctx.zig");
const op_convert = @import("../../op_convert.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    return op_convert.emitConvertIntToFloat(ctx, ins);
}
