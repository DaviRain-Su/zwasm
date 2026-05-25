//! x86_64 emit handler for `try_table` — Zone 2 per ADR-0074
//! + ADR-0114 D2. Mirror of arm64 sibling.
//!
//! Wasm spec 3.0 §3.3.10.6. Emits zero JIT bytes; registers
//! handler entries into `ExceptionTable.Builder` for the
//! FP-walk unwinder.
//!
//! Stub: emit returns `UnsupportedOp`. Real body lands at
//! 10.E-codegen-4b.
//!
//! Zone 2 (`src/engine/codegen/x86_64/ops/`).

const std = @import("std");

const meta = @import("../../../../../instruction/wasm_3_0/try_table.zig");
const ctx_mod = @import("../../ctx.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

// ADR-0113 §A/B + ADR-0114 D2 — fallthrough into inner block.
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
