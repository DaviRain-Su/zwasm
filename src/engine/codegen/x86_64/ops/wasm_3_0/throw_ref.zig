//! x86_64 emit handler for `throw_ref` — Zone 2 per ADR-0074
//! + ADR-0114 D2. Mirror of arm64 sibling.
//!
//! Wasm spec 3.0 §3.3.10.8. Pop exnref, resolve *Exception,
//! re-enter dispatcher (same shape as throw, per ADR-0114 D6).
//!
//! ## IT-3 minimum scope (current shape)
//!
//! Same as `throw.zig` sibling — JMP-rel32 placeholder to the
//! function trap stub; full dispatcher CALL + handler dispatch
//! lands at IT-6.
//!
//! Registered in `dispatch_collector.collected_x86_64_ctx_ops`.
//!
//! Zone 2 (`src/engine/codegen/x86_64/ops/`).

const meta = @import("../../../../../instruction/wasm_3_0/throw_ref.zig");
const ctx_mod = @import("../../ctx.zig");
const inst = @import("../../inst.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

// ADR-0113 §A + ADR-0114 D6 — terminator axis like throw.
pub const is_terminator: bool = true;
pub const n_successor_edges: u8 = 0;
pub const is_safepoint: bool = false;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    _ = ins;
    // IT-3 minimum — see throw.zig sibling.
    const fixup_at: u32 = @intCast(ctx.buf.items.len);
    try ctx.buf.appendSlice(ctx.allocator, inst.encJmpRel32(0).slice());
    try ctx.unreach_fixups.append(ctx.allocator, fixup_at);
    ctx.dead_code.* = true;
}
