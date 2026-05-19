//! `f64x2.sub` — Wasm 2.0 SIMD float arith op. Per-op file (Zone 1
//! identity anchor) per ADR-0023 §4.5 amend + ADR-0074.

const zir = @import("../../ir/zir.zig");
const collector = @import("../../ir/dispatch_collector.zig");

const ZirOp = zir.ZirOp;
const WasmLevel = collector.WasmLevel;
const WasiLevel = collector.WasiLevel;
const Feature = collector.Feature;

pub const op_tag: ZirOp = .@"f64x2.sub";
pub const wasm_level: ?WasmLevel = .v2_0;
pub const wasi_level: ?WasiLevel = null;
pub const enable_features: []const Feature = &.{};

pub const handlers = .{
    .validate = validate_f64x2_sub,
    .lower = lower_f64x2_sub,
    .interp = interp_f64x2_sub,
};

fn validate_f64x2_sub() collector.DispatchError!void {
    return error.NotMigrated;
}
fn lower_f64x2_sub() collector.DispatchError!void {
    return error.NotMigrated;
}
fn interp_f64x2_sub() collector.DispatchError!void {
    return error.NotMigrated;
}
