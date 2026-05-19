//! arm64 emit handler for `i32.trunc_sat_f32_s` — Zone 2 per ADR-0074.
//! Delegates to op_convert.emitTruncSat.

const meta = @import("../../../../../instruction/wasm_2_0/i32_trunc_sat_f32_s.zig");
const ctx_mod = @import("../../ctx.zig");
const op_convert = @import("../../op_convert.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    return op_convert.emitTruncSat(ctx, ins);
}
