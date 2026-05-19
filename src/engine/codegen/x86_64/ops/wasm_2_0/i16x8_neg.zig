//! x86_64 emit handler for `i16x8.neg` — Zone 2 per ADR-0074.
//! Delegates to op_simd_int_arith.emitI16x8Neg (5-arg; `op` + `spill_base_off` discarded).

const std = @import("std");

const meta = @import("../../../../../instruction/wasm_2_0/i16x8_neg.zig");
const op_simd_int_arith = @import("../../op_simd_int_arith.zig");
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
    _ = spill_base_off;
    return op_simd_int_arith.emitI16x8Neg(allocator, buf, alloc, pushed_vregs, next_vreg);
}
