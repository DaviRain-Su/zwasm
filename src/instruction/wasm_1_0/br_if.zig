//! Per-op file (Zone 1 identity anchor) per ADR-0023 §4.5 amend +
//! ADR-0074.

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .br_if;
pub const wasm_level: ?WasmLevel = .v1_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_br_if,
    .lower = lower_br_if,
    .interp = interp_br_if,
};

fn validate_br_if() collector.DispatchError!void {
    return error.NotMigrated;
}
fn lower_br_if() collector.DispatchError!void {
    return error.NotMigrated;
}
fn interp_br_if() collector.DispatchError!void {
    return error.NotMigrated;
}
