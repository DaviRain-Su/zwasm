//! `br_on_non_null` — Wasm 3.0 typed function references proposal.
//!
//! Per-op stub registered with `wasm_level: .v3_0`. See
//! `try_table.zig` for the comptime build-filter contract.
//!
//! Spec: Wasm Core 3.0 §3.3.8.8 (typed function references;
//! non-null branch).
//!
//! Zone 1 (`src/instruction/`).

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .br_on_non_null;
pub const wasm_level: ?WasmLevel = .v3_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_br_on_non_null,
    .lower = lower_br_on_non_null,
    .interp = interp_br_on_non_null,
};

fn validate_br_on_non_null() collector.DispatchError!void {
    return error.NotMigrated;
}

fn lower_br_on_non_null() collector.DispatchError!void {
    return error.NotMigrated;
}

fn interp_br_on_non_null() collector.DispatchError!void {
    return error.NotMigrated;
}
