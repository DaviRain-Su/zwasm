//! x86_64 emit handler for `throw` — Zone 2 per ADR-0074 +
//! ADR-0114 D2. Mirror of arm64 sibling.
//!
//! Wasm spec 3.0 §3.3.10.7. Per ADR-0114 D6 marshals
//! (tag_idx, payload) into argregs and CALLs the `zwasm_throw`
//! dispatcher.
//!
//! ## IT-3 minimum scope (current shape)
//!
//! Dispatcher CALL + handler-branch path deferred to IT-6. Current
//! emit is a JMP-rel32 placeholder targeting the function's trap
//! stub (same shape as `unreachable`); the stub sets trap_flag=1,
//! runs epilogue, and RETs. Net effect: every throw traps
//! unconditionally — matches the integration-plan acceptance
//! "exits via trap path (no handler installed yet)".
//!
//! Registered in `dispatch_collector.collected_x86_64_ctx_ops`.
//!
//! Zone 2 (`src/engine/codegen/x86_64/ops/`).

const meta = @import("../../../../../instruction/wasm_3_0/throw.zig");
const ctx_mod = @import("../../ctx.zig");
const inst = @import("../../inst.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

// ADR-0113 §A + ADR-0114 D6 — terminator axis.
pub const is_terminator: bool = true;
pub const n_successor_edges: u8 = 0;
pub const is_safepoint: bool = false;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    _ = ins;
    // IT-3 minimum — JMP rel32 placeholder targeting the function-end
    // trap stub (patched alongside unreachable's unreach_fixups).
    // ctx.dead_code is set so subsequent ops up to the next
    // control-flow boundary are skipped.
    const fixup_at: u32 = @intCast(ctx.buf.items.len);
    try ctx.buf.appendSlice(ctx.allocator, inst.encJmpRel32(0).slice());
    try ctx.unreach_fixups.append(ctx.allocator, fixup_at);
    ctx.dead_code.* = true;
}
