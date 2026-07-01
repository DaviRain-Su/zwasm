//! `return_call_indirect` — Wasm 3.0 tail-call proposal.
//!
//! Per-op stub registered with `wasm_level: .v3_0`. See
//! `return_call.zig` for the comptime build-filter contract.
//!
//! Spec: Wasm Core 3.0 §3.3.8.19 (tail-call proposal).
//!
//! Zone 1 (`src/instruction/`).

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .return_call_indirect;
pub const wasm_level: ?WasmLevel = .v3_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_return_call_indirect,
    .lower = lower_return_call_indirect,
    .interp = interp_return_call_indirect,
};

fn validate_return_call_indirect() collector.DispatchError!void {
    return error.NotMigrated;
}

fn lower_return_call_indirect() collector.DispatchError!void {
    return error.NotMigrated;
}

fn interp_return_call_indirect() collector.DispatchError!void {
    return error.NotMigrated;
}
