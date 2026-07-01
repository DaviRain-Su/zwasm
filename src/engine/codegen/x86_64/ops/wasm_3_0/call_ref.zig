//! x86_64 emit handler for `call_ref` — Zone 2 per ADR-0074.
//!
//! Delegates to `op_call.emitCallRefCtx`. Call through a typed
//! funcref (`*FuncEntity` from `ref.func`): null-check + funcptr
//! deref (`funcentity_funcptr_offset`) + CALL. No runtime sig check
//! (validator guarantees the funcref's type ⊑ `$sig`).
//!
//! Wasm spec 3.0 §3.3.8.13 (call_ref). `ins.payload` = type_idx.
//! Registered in `dispatch_collector.collected_x86_64_ctx_ops`.
//!
//! Zone 2 (`src/engine/codegen/x86_64/ops/`).

const meta = @import("../../../../../instruction/wasm_3_0/call_ref.zig");
const ctx_mod = @import("../../ctx.zig");
const op_call = @import("../../op_call.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    return op_call.emitCallRefCtx(ctx, ins);
}
