//! x86_64 emit handler for `i32.trunc_sat_f32_s` — Zone 2 per ADR-0074.
//! Delegates to op_convert.emitFpTruncSatSigned.

const std = @import("std");

const meta = @import("../../../../../instruction/wasm_2_0/i32_trunc_sat_f32_s.zig");
const op_convert = @import("../../op_convert.zig");
const regalloc = @import("../../../shared/regalloc.zig");
const types = @import("../../types.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(
    allocator: std.mem.Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    pushed_vregs: *std.ArrayList(u32),
    next_vreg: *u32,
    spill_base_off: u32,
    op: zir.ZirOp,
) types.Error!void {
    return op_convert.emitFpTruncSatSigned(allocator, buf, alloc, pushed_vregs, next_vreg, spill_base_off, op);
}
