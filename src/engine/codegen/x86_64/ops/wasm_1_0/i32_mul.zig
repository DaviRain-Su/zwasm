//! x86_64 emit handler for `i32.mul` — Zone 2 per ADR-0074.
//! Delegates to op_alu_int.emitI32Binary.
//!
//! Wasm spec §3.3.1. Intel SDM Vol 2A §3.2 IMUL.
//!
//! Zone 2 (`src/engine/codegen/x86_64/ops/`).

const std = @import("std");

const meta = @import("../../../../../instruction/wasm_1_0/i32_mul.zig");
const op_alu_int = @import("../../op_alu_int.zig");
const regalloc = @import("../../../shared/regalloc.zig");
const types = @import("../../types.zig");
const zir = @import("../../../../../ir/zir.zig");

const Allocator = std.mem.Allocator;
const Error = types.Error;

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    pushed_vregs: *std.ArrayList(u32),
    next_vreg: *u32,
    spill_base_off: u32,
    op: zir.ZirOp,
) Error!void {
    return op_alu_int.emitI32Binary(allocator, buf, alloc, pushed_vregs, next_vreg, spill_base_off, op);
}
