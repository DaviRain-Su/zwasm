//! `struct.get_s` — Wasm 3.0 GC proposal.
//!
//! Per-op stub registered with `wasm_level: .v3_0`. See
//! `try_table.zig` for the comptime build-filter contract.
//!
//! Spec: Wasm Core 3.0 §3.3.13.7 (GC; struct field signed
//! narrow load — for packed i8 / i16 fields).
//!
//! Zone 1 (`src/instruction/`).

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .@"struct.get_s";
pub const wasm_level: ?WasmLevel = .v3_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_struct_get_s,
    .lower = lower_struct_get_s,
    .interp = interp_struct_get_s,
};

fn validate_struct_get_s() collector.DispatchError!void {
    return error.NotMigrated;
}

fn lower_struct_get_s() collector.DispatchError!void {
    return error.NotMigrated;
}

fn interp_struct_get_s() collector.DispatchError!void {
    return error.NotMigrated;
}
