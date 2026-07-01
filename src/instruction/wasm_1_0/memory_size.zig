//! Per-op file (Zone 1 identity anchor) per ADR-0023 §4.5 amend +
//! ADR-0074 + §9.12-B / B71 (memory.grow/size meta backfill).

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .@"memory.size";
pub const wasm_level: ?WasmLevel = .v1_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_memory_size,
    .lower = lower_memory_size,
    .interp = interp_memory_size,
};

fn validate_memory_size() collector.DispatchError!void {
    return error.NotMigrated;
}
fn lower_memory_size() collector.DispatchError!void {
    return error.NotMigrated;
}
fn interp_memory_size() collector.DispatchError!void {
    return error.NotMigrated;
}
