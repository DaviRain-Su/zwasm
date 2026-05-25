//! arm64 emit handler for `throw` — Zone 2 per ADR-0074 +
//! ADR-0114 D2.
//!
//! Wasm spec 3.0 §3.3.10.7. Per ADR-0114 D6 the full throw op
//! marshals (tag_idx, payload) into argregs and CALLs the
//! `zwasm_throw` dispatcher; on .uncaught it sets trap_flag=1
//! and returns, on .handler it JMPs to the landing pad.
//!
//! ## IT-3 minimum scope (current shape)
//!
//! The dispatcher CALL + handler-branch path is deferred to IT-6
//! (trampoline glue). For IT-3 the throw site emits as an
//! unconditional branch to the function's trap stub (= same shape
//! as `unreachable`), which sets trap_flag=1 + clean epilogue +
//! RET. Net effect: ANY throw traps unconditionally, regardless
//! of installed handlers. This matches the integration-plan
//! acceptance "exits via trap path (no handler installed yet)";
//! handler dispatch arrives once the trampoline glue exists.
//!
//! Zone 2 (`src/engine/codegen/arm64/ops/`).

const meta = @import("../../../../../instruction/wasm_3_0/throw.zig");
const ctx_mod = @import("../../ctx.zig");
const gpr = @import("../../gpr.zig");
const inst = @import("../../inst.zig");
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
    _ = ins;
    // IT-3 minimum: emit an unconditional B placeholder targeting
    // the function's trap stub (patched at function-end alongside
    // `unreachable` / bounds-check fixups). bits 31..26 = 000101
    // identifies it to the patcher as an unconditional B (vs the
    // B.cond shape used by bounds checks).
    const fixup_at: u32 = @intCast(ctx.buf.items.len);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encB(0));
    try ctx.bounds_fixups.append(ctx.allocator, fixup_at);
}
