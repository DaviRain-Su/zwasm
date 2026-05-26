//! arm64 emit handler for `return_call` — Zone 2 per-arch op file
//! per ADR-0074 + ADR-0112 D2 (separate `op_tail_call.zig` shape;
//! not an extension of `op_call.zig`).
//!
//! Wasm spec 3.0 §3.3.8.18 (tail-call proposal). Frame teardown
//! before the branch (vs after for regular `call`): consume
//! caller's frame, B directly to callee body (PC-relative; linker
//! patches imm26) — no LR, callee returns to caller's caller.
//!
//! Delegation per ADR-0112 D2: orchestration lives in
//! `arm64/op_tail_call.zig::emitDirectReturnCall`; this file
//! stays the dispatch-table entry point.
//!
//! Zone 2 (`src/engine/codegen/arm64/ops/`).

const meta = @import("../../../../../instruction/wasm_3_0/return_call.zig");
const ctx_mod = @import("../../ctx.zig");
const op_tail_call = @import("../../op_tail_call.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

// ADR-0113 §A — regalloc 3-axis classification. `return_call`
// is a terminator: it consumes the caller's frame and Branches
// without LR, so no fallthrough exists. Zero successor edges
// (the branch target is the callee, but the regalloc
// successor-edge axis counts in-function CFG edges; tail-call
// leaves the function). NOT a safepoint per ADR-0112 D7 (no
// allocator / host-call / signal-check between teardown and
// jump — comptime-asserted).
pub const is_terminator: bool = true;
pub const n_successor_edges: u8 = 0;
pub const is_safepoint: bool = false;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    return op_tail_call.emitDirectReturnCall(ctx, ins);
}
