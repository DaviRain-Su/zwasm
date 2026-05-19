//! arm64 emit handler for `br_if` — Zone 2 per ADR-0074.

const meta = @import("../../../../../instruction/wasm_1_0/br_if.zig");
const ctx_mod = @import("../../ctx.zig");
const op_control = @import("../../op_control.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    return op_control.emitBrIf(ctx, ins);
}
