//! x86_64 emit handler for `i32.div_s` — Zone 2 per-arch op file
//! per ADR-0074 + ADR-0075 (B54 PoC for the `(ctx, ins)` shape).
//!
//! Identity anchor (`op_tag`, `wasm_level`, `wasi_level`) lives at
//! `src/instruction/wasm_1_0/i32_div_s.zig` (Zone 1). The emit body
//! delegates to `op_alu_int.emitI32DivS`, which threads
//! `ctx.bounds_fixups` for the DE / 0E trap placeholders.
//!
//! Wasm spec §4.4.1 (i32.div_s) — signed 32-bit integer divide;
//! traps on divisor=0 or `INT_MIN / -1`.
//! Intel SDM Vol 2A `IDIV r/m32` (CDQ ; IDIV) — sign-extended
//! dividend in EDX:EAX; quotient in EAX, remainder in EDX.
//!
//! ## Registration note (B54)
//!
//! This file is structurally complete for the `(ctx, ins)` shape
//! but is **not** registered in
//! `dispatch_collector.zig::collected_x86_64_ops` yet — the
//! existing tuple's call shape is the legacy 7-arg form
//! (incompatible with `(ctx, ins)` at comptime). The dispatcher
//! cutover happens at B6x+1 (per ADR-0075 §Implementation plan):
//! once every x86_64 per-op file ships the `(ctx, ins)` shape,
//! the dispatcher's `args` tuple flips to `.{ &ctx, &ins }` in a
//! single commit. Until then, `emit.zig`'s giant switch wires
//! migrated ops directly via `op_alu_int.emitI32DivS(&ctx, &ins)`.
//!
//! Zone 2 (`src/engine/codegen/x86_64/ops/`).

const meta = @import("../../../../../instruction/wasm_1_0/i32_div_s.zig");
const ctx_mod = @import("../../ctx.zig");
const op_alu_int = @import("../../op_alu_int.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    return op_alu_int.emitI32DivS(ctx, ins);
}
