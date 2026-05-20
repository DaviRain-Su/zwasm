//! `try_table` — Wasm 3.0 exception-handling (EH) proposal.
//!
//! Per-op stub registered with `wasm_level: .v3_0`. Under
//! `-Dwasm=v2_0` / `-Dwasm=v1_0`, the dispatcher's comptime
//! build-option filter rejects this op with
//! `error.UnsupportedOpForBuildLevel` (Phase 10 comptime-reject
//! infra at `d641dcd8`). Under `-Dwasm=v3_0` (default), the
//! stub handler returns `error.NotMigrated`; legacy dispatch
//! retains authority until Phase 10 EH impl lands.
//!
//! Spec: Wasm Core 3.0 §3.3.8.13 (exception-handling).
//!
//! Zone 1 (`src/instruction/`).

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .try_table;
pub const wasm_level: ?WasmLevel = .v3_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_try_table,
    .lower = lower_try_table,
    .interp = interp_try_table,
};

fn validate_try_table() collector.DispatchError!void {
    return error.NotMigrated;
}

fn lower_try_table() collector.DispatchError!void {
    return error.NotMigrated;
}

fn interp_try_table() collector.DispatchError!void {
    return error.NotMigrated;
}
