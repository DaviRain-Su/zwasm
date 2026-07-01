//! arm64 emit handler for `i32.trunc_f64_u` — Zone 2 per ADR-0074.

const meta = @import("../../../../../instruction/wasm_1_0/i32_trunc_f64_u.zig");
const ctx_mod = @import("../../ctx.zig");
const bounds_check = @import("../../bounds_check.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    return bounds_check.emitTrappingTruncF64(ctx, ins);
}
