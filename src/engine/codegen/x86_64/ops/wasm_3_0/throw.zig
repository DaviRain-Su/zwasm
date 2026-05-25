//! x86_64 emit handler for `throw` — Zone 2 per ADR-0074 +
//! ADR-0114 D2. Mirror of arm64 sibling.
//!
//! Wasm spec 3.0 §3.3.10.7. Marshals (tag_idx, payload) into
//! argregs and CALLs the `zwasm_throw` dispatcher.
//!
//! Stub: emit returns `UnsupportedOp`. Real body lands at
//! 10.E-codegen-4c.
//!
//! Zone 2 (`src/engine/codegen/x86_64/ops/`).

const meta = @import("../../../../../instruction/wasm_3_0/throw.zig");
const ctx_mod = @import("../../ctx.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

// ADR-0113 §A + ADR-0114 D6 — terminator axis.
pub const is_terminator: bool = true;
pub const n_successor_edges: u8 = 0;
pub const is_safepoint: bool = false;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    _ = ctx;
    _ = ins;
    return error.UnsupportedOp;
}
