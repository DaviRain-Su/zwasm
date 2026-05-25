//! arm64 emit handler for `throw_ref` — Zone 2 per ADR-0074
//! + ADR-0114 D2.
//!
//! Wasm spec 3.0 §3.3.10.8. Pop the exnref, resolve its
//! wrapped `*Exception`, write to `pending_exception`, then
//! re-enter the dispatcher (same shape as throw). Per
//! ADR-0114 D6.
//!
//! ## IT-3 minimum scope (current shape)
//!
//! Same as `throw.zig` sibling — dispatcher CALL + .handler
//! branch defers to IT-6; current emit is a B-placeholder to
//! the function's trap stub.
//!
//! Zone 2 (`src/engine/codegen/arm64/ops/`).

const meta = @import("../../../../../instruction/wasm_3_0/throw_ref.zig");
const ctx_mod = @import("../../ctx.zig");
const gpr = @import("../../gpr.zig");
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
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encB(0));
    try ctx.bounds_fixups.append(ctx.allocator, fixup_at);
}
