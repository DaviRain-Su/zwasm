//! arm64 emit handler for `throw` — Zone 2 per ADR-0074 +
//! ADR-0114 D2.
//!
//! Wasm spec 3.0 §3.3.10.7. Per ADR-0114 D6 the throw op
//! marshals (tag_idx, payload) into argregs and CALLs the
//! `zwasm_throw` dispatcher (`shared/zwasm_throw.zig`). The
//! dispatcher walks the FP chain via `unwind.walk` and either
//! jumps to a try_table landing pad (.handler) or sets
//! trap_flag=1 and returns (.uncaught).
//!
//! Stub: emit returns `UnsupportedOp`. Real body (payload
//! marshal + tag_idx load + CALL dispatcher) lands at
//! 10.E-codegen-4c.
//!
//! Zone 2 (`src/engine/codegen/arm64/ops/`).

const meta = @import("../../../../../instruction/wasm_3_0/throw.zig");
const ctx_mod = @import("../../ctx.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

// ADR-0113 §A + ADR-0114 D6 — regalloc 3-axis classification.
// throw is a terminator: control transfers via the dispatcher
// to either a landing pad (cross-function jump) or the entry
// shim (uncaught trap return); never falls through. Zero
// in-function CFG successor edges. Not a safepoint — the
// throw site itself does no allocation (the dispatcher
// allocates Exception lazily after the unwind decision); the
// regalloc treats it like tail-call (terminator without
// safepoint).
pub const is_terminator: bool = true;
pub const n_successor_edges: u8 = 0;
pub const is_safepoint: bool = false;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    _ = ctx;
    _ = ins;
    return error.UnsupportedOp;
}
