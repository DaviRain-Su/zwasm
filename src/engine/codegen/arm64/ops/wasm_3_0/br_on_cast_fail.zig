//! arm64 emit handler for `br_on_cast_fail` — Wasm 3.0 GC §3.3.5.5.
//! Identical emit to `br_on_cast` (the branch sense is read from `ins.op`,
//! which inverts the cast bool before the shared `branchOnReg`), so this
//! re-exports `br_on_cast.zig`'s `emit` and only differs in `op_tag`.

const meta = @import("../../../../../instruction/wasm_3_0/br_on_cast_fail.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;
pub const emit = @import("br_on_cast.zig").emit;
