//! `throw_ref` — Wasm 3.0 exception-handling (EH) proposal.
//!
//! Per-op stub registered with `wasm_level: .v3_0`. See
//! `try_table.zig` for the comptime build-filter contract.
//!
//! Spec: Wasm Core 3.0 §3.3.8.15 (exception-handling; rethrow
//! via an `exnref` operand).
//!
//! Zone 1 (`src/instruction/`).

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .throw_ref;
pub const wasm_level: ?WasmLevel = .v3_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_throw_ref,
    .lower = lower_throw_ref,
    .interp = interp_throw_ref,
};

fn validate_throw_ref() collector.DispatchError!void {
    return error.NotMigrated;
}

fn lower_throw_ref() collector.DispatchError!void {
    return error.NotMigrated;
}

fn interp_throw_ref() collector.DispatchError!void {
    return error.NotMigrated;
}
