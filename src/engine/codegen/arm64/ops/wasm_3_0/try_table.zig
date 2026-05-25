//! arm64 emit handler for `try_table` — Zone 2 per ADR-0074
//! + ADR-0114 D2.
//!
//! Wasm spec 3.0 §3.3.10.6 (try_table). Per ADR-0114 D2 the
//! try_table itself emits **zero JIT bytes** — it only
//! registers handler entries into the per-Instance
//! `ExceptionTable.Builder` so the FP-walk unwinder can find
//! them at throw time. The body's PC range is recorded in the
//! HandlerEntry; the JIT body for the inner block continues
//! to emit normally.
//!
//! Stub: emit returns `UnsupportedOp`. Real body (Builder.add
//! per catch clause + recursive emit of inner block) lands at
//! 10.E-codegen-4b.
//!
//! Zone 2 (`src/engine/codegen/arm64/ops/`).

const std = @import("std");

const meta = @import("../../../../../instruction/wasm_3_0/try_table.zig");
const ctx_mod = @import("../../ctx.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

// ADR-0113 §A/B + ADR-0114 D2 — regalloc 3-axis classification.
// try_table falls through into the inner block (NOT a
// terminator); the per-op constant n_successor_edges = 1
// covers the catch-all shape (1 normal-fallthrough edge). The
// per-callsite N (1 + N_catch_clauses for the EH-aware
// callsite metadata per ADR-0113 D3) is populated at lower
// time when the parsed catch-vec count is known. Not a
// safepoint — try_table itself does no GC-observable work
// (handler registration is build-time data; the per-Instance
// ExceptionTable.Builder accumulates outside the emit hot
// path).
pub const is_terminator: bool = false;
pub const n_successor_edges: u8 = 1;
pub const is_safepoint: bool = false;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    _ = ins;
    // IT-1 invariant — compile() MUST allocate the per-function
    // ExceptionTable.Builder when any try_table op is present.
    // Failure here means the IT-1 scan/wiring regressed.
    std.debug.assert(ctx.exception_table_builder != null);
    return error.UnsupportedOp;
}
