//! arm64 emit handler for `i32.xor` — Zone 2 per ADR-0074.
//! Delegates to op_alu_int.emitI32Binary.
//!
//! Wasm spec §3.3.1. Arm IHI 0055 §C6.2 (W-form EOR).
//!
//! Zone 2 (`src/engine/codegen/arm64/ops/`).

const meta = @import("../../../../../instruction/wasm_1_0/i32_xor.zig");
const ctx_mod = @import("../../ctx.zig");
const op_alu_int = @import("../../op_alu_int.zig");
const zir = @import("../../../../../ir/zir.zig");

const EmitCtx = ctx_mod.EmitCtx;
const Error = ctx_mod.Error;
const ZirInstr = zir.ZirInstr;

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *EmitCtx, ins: *const ZirInstr) Error!void {
    return op_alu_int.emitI32Binary(ctx, ins);
}
