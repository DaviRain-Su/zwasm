//! Per-op file (Zone 1 identity anchor) per ADR-0023 §4.5 amend +
//! ADR-0074 + §9.12-B / B66 (meta-file backfill).

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .@"local.get";
pub const wasm_level: ?WasmLevel = .v1_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_local_get,
    .lower = lower_local_get,
    .interp = interp_local_get,
};

fn validate_local_get() collector.DispatchError!void {
    return error.NotMigrated;
}
fn lower_local_get() collector.DispatchError!void {
    return error.NotMigrated;
}
fn interp_local_get() collector.DispatchError!void {
    return error.NotMigrated;
}
