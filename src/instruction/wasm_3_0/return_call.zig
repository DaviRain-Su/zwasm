//! `return_call` — Wasm 3.0 tail-call proposal.
//!
//! Per-op stub registered with `wasm_level: .v3_0`. Under build
//! configurations with `-Dwasm=v2_0` or lower, the dispatcher's
//! comptime build-option filter rejects this op with
//! `error.UnsupportedOpForBuildLevel` (per ADR-0073 + §9.12-G
//! Phase 10 prep at `d641dcd8`). Under `-Dwasm=v3_0` (default),
//! the stub handler returns `error.NotMigrated` and the legacy
//! dispatch path (lower.zig / validator.zig) retains authority
//! until Phase 10's tail-call implementation lands.
//!
//! Spec: Wasm Core 3.0 §3.3.8.18 (tail-call proposal).
//!
//! Zone 1 (`src/instruction/`).

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .return_call;
pub const wasm_level: ?WasmLevel = .v3_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_return_call,
    .lower = lower_return_call,
    .interp = interp_return_call,
};

fn validate_return_call() collector.DispatchError!void {
    return error.NotMigrated;
}

fn lower_return_call() collector.DispatchError!void {
    return error.NotMigrated;
}

fn interp_return_call() collector.DispatchError!void {
    return error.NotMigrated;
}
