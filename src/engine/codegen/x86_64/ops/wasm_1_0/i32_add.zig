//! x86_64 emit handler for `i32.add` — Zone 2 per-arch op file per
//! ADR-0074.
//!
//! Identity anchor (`op_tag`, `wasm_level`, `wasi_level`) lives at
//! `src/instruction/wasm_1_0/i32_add.zig` (Zone 1). This file mirrors
//! the metadata for the Zone 2 collector's contract check and provides
//! the x86_64 emit body.
//!
//! Wasm spec §3.3.1 (numeric binary op — `i32.add`).
//! Intel SDM Vol 2A §3.2 `ADD r32, r32`.
//!
//! ## State at B12
//!
//! Real body — delegates to the existing 7-arg
//! `op_alu_int.emitI32Binary` (handles i32.add / sub / mul / and /
//! or / xor via `op` dispatch internally). The collector wire at
//! `x86_64/emit.zig` skips the legacy switch arm for `i32.add`
//! because the dispatcher returns `true`. Mirror of B11 (arm64).
//!
//! Future cleanup (post-§9.12-B exit): once all 6 i32 binary ALU ops
//! migrate to per-arch op files, `op_alu_int.emitI32Binary`'s
//! op-keyed inner switch becomes vestigial and the function
//! decomposes per-op.
//!
//! Zone 2 (`src/engine/codegen/x86_64/ops/`).

const std = @import("std");

const meta = @import("../../../../../instruction/wasm_1_0/i32_add.zig");
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
