//! ARM64 emit pass — `table.get` / `table.set` / `table.size`
//! handlers (§9.9 / 9.9-m-2a per ADR-0058).
//!
//! Each declared table has a `TableSlice` descriptor in the JIT
//! runtime's `tables_ptr` array (stride 16 bytes per ADR-0058);
//! the JIT body loads `refs` + `len` from the indexed descriptor
//! then performs a bounds-checked load/store against
//! `refs[idx]` (8-byte ref slot).
//!
//! Per-op shape (Wasm spec §4.4.10–12):
//!
//!   table.get x:
//!     LDR  X10, [X19, #tables_ptr_off]        ; tables_ptr
//!     LDR  X11, [X10, #(tableidx*16)]         ; refs ptr
//!     LDR  W12, [X10, #(tableidx*16)+8]       ; len
//!     ORR  W17, WZR, W_idx                    ; zero-ext idx into ip1
//!     CMP  W17, W12                           ; idx vs len
//!     B.HS trap_stub                          ; bounds_fixups
//!     LDR  Xresult, [X11, X17, LSL #3]        ; refs[idx]
//!     (store back to spill slot if needed)
//!
//!   table.set x:
//!     (same prologue + bounds check)
//!     STR  Xval, [X11, X17, LSL #3]
//!
//!   table.size x:
//!     LDR  X10, [X19, #tables_ptr_off]
//!     LDR  W_result, [X10, #(tableidx*16)+8]  ; push len as i32
//!
//! X10 / X11 / X12 / X17 are caller-saved scratch within this
//! handler (X10/X11/X12 follow op_memory's scratch convention;
//! X17 is the bounds-check scratch already used by op_memory and
//! op_call's emit paths but the handler boundaries don't overlap).
//!
//! Zone 2 (`src/engine/codegen/arm64/`).

const zir = @import("../../../ir/zir.zig");
const inst = @import("inst.zig");
const ctx_mod = @import("ctx.zig");
const gpr = @import("gpr.zig");
const trace = @import("../../../diagnostic/trace.zig");
const abi = @import("abi.zig");
const jit_abi = @import("../shared/jit_abi.zig");

const ZirInstr = zir.ZirInstr;
const EmitCtx = ctx_mod.EmitCtx;
const Error = ctx_mod.Error;

/// Wasm spec §4.4.10 (table.get) — pop i32 idx, push tables[x][idx]
/// as a reference Value (8-byte). Traps `OutOfBoundsTableAccess` on
/// idx >= table.len via the shared `bounds_fixups` channel.
///
/// Operand capture happens BEFORE the X10/X11/X12 LDR sequence
/// because the regalloc may have parked the operand vreg in
/// X9..X13 — clobbering it without snapshotting first would lose
/// the operand's value (silent miscompile mirror of the m-5 trap-
/// stub R15 prescan bug).
pub fn emitTableGet(ctx: *EmitCtx, ins: *const ZirInstr) Error!void {
    const tableidx = ins.payload;
    // imm12 budget for X-form LDR: byte_off scaled by 8 → max
    // tableidx for the X-form refs load = 32760/16 = 2047. For
    // the W-form len load (scaled by 4), max byte_off = 16380 →
    // tableidx ≤ (16380-8)/16 = 1023. The W-form path is tighter.
    if (tableidx >= 1024) return Error.UnsupportedOp;
    const tbl_off: u15 = @intCast(@as(u32, tableidx) * 16);

    if (ctx.pushed_vregs.items.len < 1) return Error.AllocationMissing;
    const idx_v = ctx.pushed_vregs.pop().?;

    // Step A: snapshot idx into W17 (intra-procedure scratch, never
    // in the regalloc pool — survives the X10/X11/X12 clobbering
    // below).
    const w_idx_src = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, idx_v, 0);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encOrrRegW(17, 31, w_idx_src));

    // Step B: read TableSlice[tableidx]. Safe to clobber X10/X11/X12.
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrImm(10, abi.runtime_ptr_save_gpr, jit_abi.tables_ptr_off));
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrImm(11, 10, tbl_off));
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrImmW(12, 10, @intCast(@as(u32, tbl_off) + 8)));

    // Step C: CMP W17, W12 ; B.HS trap.
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encCmpRegW(17, 12));
    {
        const fixup_at: u32 = @intCast(ctx.buf.items.len);
        try gpr.writeU32(ctx.allocator, ctx.buf, inst.encBCond(.hs, 0));
        try ctx.bounds_fixups.append(ctx.allocator, fixup_at);
        trace.writeBounds(ctx.func.func_idx, fixup_at);
    }

    // Step D: allocate the result vreg and load.
    const result = ctx.next_vreg.*;
    ctx.next_vreg.* += 1;
    if (result >= ctx.alloc.slots.len) return Error.SlotOverflow;
    const xd = try gpr.gprDefSpilled(ctx.alloc, result, 0);

    // LDR Xd, [X11, X17, LSL #3]
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrXRegLsl3(xd, 11, 17));
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, result);
}

/// Wasm spec §4.4.11 (table.set) — pop reftype value then i32 idx,
/// write `tables[x][idx] = val`. Traps `OutOfBoundsTableAccess` on
/// idx >= table.len.
pub fn emitTableSet(ctx: *EmitCtx, ins: *const ZirInstr) Error!void {
    const tableidx = ins.payload;
    if (tableidx >= 1024) return Error.UnsupportedOp;
    const tbl_off: u15 = @intCast(@as(u32, tableidx) * 16);

    if (ctx.pushed_vregs.items.len < 2) return Error.AllocationMissing;
    const val_v = ctx.pushed_vregs.pop().?;
    const idx_v = ctx.pushed_vregs.pop().?;

    // Step A: snapshot operands into intra-procedure scratch BEFORE
    // touching X10/X11/X12 (regalloc may park operand vregs in
    // X9..X13). idx → W17; val → X16 (full 64-bit ref).
    const w_idx_src = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, idx_v, 0);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encOrrRegW(17, 31, w_idx_src));
    const x_val_src = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, val_v, 1);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encOrrReg(16, 31, x_val_src));

    // Step B: read TableSlice[tableidx].
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrImm(10, abi.runtime_ptr_save_gpr, jit_abi.tables_ptr_off));
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrImm(11, 10, tbl_off));
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrImmW(12, 10, @intCast(@as(u32, tbl_off) + 8)));

    // Step C: CMP W17, W12 ; B.HS trap.
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encCmpRegW(17, 12));
    {
        const fixup_at: u32 = @intCast(ctx.buf.items.len);
        try gpr.writeU32(ctx.allocator, ctx.buf, inst.encBCond(.hs, 0));
        try ctx.bounds_fixups.append(ctx.allocator, fixup_at);
        trace.writeBounds(ctx.func.func_idx, fixup_at);
    }

    // Step D: STR X16 (val), [X11 + X17 * 8] — write refs[idx].
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encStrXRegLsl3(16, 11, 17));
}

/// Wasm spec §4.4.12 (table.size) — push current `tables[x].len`
/// as i32. No trap conditions; the validator already rejected
/// out-of-range tableidx.
pub fn emitTableSize(ctx: *EmitCtx, ins: *const ZirInstr) Error!void {
    const tableidx = ins.payload;
    if (tableidx >= 1024) return Error.UnsupportedOp;
    const len_off: u14 = @intCast(@as(u32, tableidx) * 16 + 8);

    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrImm(10, abi.runtime_ptr_save_gpr, jit_abi.tables_ptr_off));

    const result = ctx.next_vreg.*;
    ctx.next_vreg.* += 1;
    if (result >= ctx.alloc.slots.len) return Error.SlotOverflow;
    const wd = try gpr.gprDefSpilled(ctx.alloc, result, 0);

    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encLdrImmW(wd, 10, len_off));
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, result);
}
