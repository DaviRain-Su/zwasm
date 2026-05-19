//! x86_64 emit handler for `f32x4.mul` — Zone 2 per ADR-0074.

const std = @import("std");

const meta = @import("../../../../../instruction/wasm_2_0/f32x4_mul.zig");
const op_simd_float = @import("../../op_simd_float.zig");
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
    _ = op;
    return op_simd_float.emitF32x4Mul(allocator, buf, alloc, pushed_vregs, next_vreg, spill_base_off);
}
