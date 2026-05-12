//! x86_64 emit pass — `table.get` / `table.set` / `table.size`
//! handlers (§9.9 / 9.9-m-2a per ADR-0058).
//!
//! Mirror of `arm64/op_table.zig`. The JIT body reads the
//! per-table `TableSlice` descriptor from `[R15 + tables_ptr_off]`,
//! indexes by `tableidx * 16` (stride matches SegmentSlice m-3b),
//! and performs a bounds-checked load/store against `refs[idx]`.
//!
//! Per-op shape (Wasm spec §4.4.10–12):
//!
//!   table.get x:
//!     MOV  RAX, [R15 + tables_ptr_off]            ; tables_ptr
//!     MOV  R11, [RAX + (tableidx*16)]             ; refs ptr
//!     MOV  R10d, [RAX + (tableidx*16)+8]          ; len (zero-ext to 64)
//!     MOV  EDX, W_idx                              ; stage idx in EDX
//!     CMP  EDX, R10d
//!     JAE  trap_stub                               ; bounds_fixups
//!     MOV  Rdst, [R11 + RDX*8]                     ; refs[idx]
//!     (store back to spill slot if needed)
//!
//!   table.set x:
//!     (same prologue + bounds check)
//!     MOV  [R11 + RDX*8], Rval
//!
//!   table.size x:
//!     MOV  RAX, [R15 + tables_ptr_off]
//!     MOV  Rdst_d, [RAX + (tableidx*16)+8]         ; push len as i32
//!
//! RAX / R10 / R11 / RDX are private scratch within the handler
//! (RAX is global scratch outside the regalloc pool; R10/R11 are
//! reserved for memory-op style scratch; RDX is the idx holder
//! mirror of op_memory.emitMemoryInit's pattern).
//!
//! Zone 2 (`src/engine/codegen/x86_64/`).

const std = @import("std");

const regalloc = @import("../shared/regalloc.zig");
const inst = @import("inst.zig");
const inst_mem = @import("inst_mem.zig");
const abi = @import("abi.zig");
const gpr = @import("gpr.zig");
const jit_abi = @import("../shared/jit_abi.zig");
const types = @import("types.zig");
const trace = @import("../../../diagnostic/trace.zig");

const Allocator = std.mem.Allocator;
const Error = types.Error;

/// Wasm spec §4.4.10 (table.get) — pop i32 idx, push tables[x][idx]
/// as a reference Value (8-byte). Traps `OutOfBoundsTableAccess` on
/// idx >= table.len via the shared `bounds_fixups` channel.
pub fn emitTableGet(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    pushed_vregs: *std.ArrayList(u32),
    next_vreg: *u32,
    bounds_fixups: *std.ArrayList(u32),
    spill_base_off: u32,
    func_idx: u32,
    tableidx: u32,
) Error!void {
    // Encoding-budget guard. The disp32 form always suffices for
    // realistic table counts; match the arm64 path's 1024 cap so the
    // two arches reject the same module shapes.
    if (tableidx >= 1024) return Error.UnsupportedOp;
    const tbl_disp: i32 = @intCast(tableidx * 16);

    if (pushed_vregs.items.len < 1) return Error.AllocationMissing;
    const idx_v = pushed_vregs.pop().?;

    // Load tables_ptr → RAX; refs → R11; len → R10d.
    try buf.appendSlice(allocator, inst.encMovR64FromMemDisp32(.rax, abi.runtime_ptr_save_gpr, jit_abi.tables_ptr_off).slice());
    try buf.appendSlice(allocator, inst.encMovR64FromMemDisp32(.r11, .rax, tbl_disp).slice());
    try buf.appendSlice(allocator, inst.encMovR32FromMemDisp32(.r10, .rax, tbl_disp + 8).slice());

    // Stage idx in EDX (32-bit MOV zero-extends to RDX implicitly).
    const idx_r = try gpr.gprLoadSpilled(allocator, buf, alloc, spill_base_off, idx_v, 0);
    try buf.appendSlice(allocator, inst.encMovRR(.d, .rdx, idx_r).slice());

    // CMP EDX, R10d ; JAE trap.
    try buf.appendSlice(allocator, inst.encCmpRR(.d, .rdx, .r10).slice());
    {
        const fixup_at: u32 = @intCast(buf.items.len);
        try buf.appendSlice(allocator, inst.encJccRel32(.ae, 0).slice());
        try bounds_fixups.append(allocator, fixup_at);
        trace.writeBounds(func_idx, fixup_at);
    }

    // Allocate result vreg and load.
    const result_v = next_vreg.*;
    next_vreg.* += 1;
    if (result_v >= alloc.slots.len) return Error.SlotOverflow;
    const dst_r = try gpr.gprDefSpilled(alloc, result_v, 0);

    // MOV Rdst, [R11 + RDX*8]
    try buf.appendSlice(allocator, inst_mem.encMovR64FromBaseIdxLsl3(dst_r, .r11, .rdx).slice());
    try gpr.gprStoreSpilled(allocator, buf, alloc, spill_base_off, result_v, 0);
    try pushed_vregs.append(allocator, result_v);
}

/// Wasm spec §4.4.11 (table.set) — pop reftype value then i32 idx,
/// write `tables[x][idx] = val`.
pub fn emitTableSet(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    pushed_vregs: *std.ArrayList(u32),
    bounds_fixups: *std.ArrayList(u32),
    spill_base_off: u32,
    func_idx: u32,
    tableidx: u32,
) Error!void {
    if (tableidx >= 1024) return Error.UnsupportedOp;
    const tbl_disp: i32 = @intCast(tableidx * 16);

    if (pushed_vregs.items.len < 2) return Error.AllocationMissing;
    const val_v = pushed_vregs.pop().?;
    const idx_v = pushed_vregs.pop().?;

    // Load tables_ptr → RAX; refs → R11; len → R10d.
    try buf.appendSlice(allocator, inst.encMovR64FromMemDisp32(.rax, abi.runtime_ptr_save_gpr, jit_abi.tables_ptr_off).slice());
    try buf.appendSlice(allocator, inst.encMovR64FromMemDisp32(.r11, .rax, tbl_disp).slice());
    try buf.appendSlice(allocator, inst.encMovR32FromMemDisp32(.r10, .rax, tbl_disp + 8).slice());

    // Stage idx in EDX.
    const idx_r = try gpr.gprLoadSpilled(allocator, buf, alloc, spill_base_off, idx_v, 0);
    try buf.appendSlice(allocator, inst.encMovRR(.d, .rdx, idx_r).slice());

    // CMP EDX, R10d ; JAE trap.
    try buf.appendSlice(allocator, inst.encCmpRR(.d, .rdx, .r10).slice());
    {
        const fixup_at: u32 = @intCast(buf.items.len);
        try buf.appendSlice(allocator, inst.encJccRel32(.ae, 0).slice());
        try bounds_fixups.append(allocator, fixup_at);
        trace.writeBounds(func_idx, fixup_at);
    }

    // Load val as 64-bit (stage 1 to avoid clobbering idx in stage 0).
    const val_r = try gpr.gprLoadSpilled(allocator, buf, alloc, spill_base_off, val_v, 1);
    // MOV [R11 + RDX*8], Rval
    try buf.appendSlice(allocator, inst_mem.encStoreR64MemBaseIdxLsl3(val_r, .r11, .rdx).slice());
}

/// Wasm spec §4.4.12 (table.size) — push tables[x].len as i32.
/// No trap conditions; validator pre-rejects out-of-range tableidx.
pub fn emitTableSize(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    pushed_vregs: *std.ArrayList(u32),
    next_vreg: *u32,
    spill_base_off: u32,
    tableidx: u32,
) Error!void {
    if (tableidx >= 1024) return Error.UnsupportedOp;
    const len_disp: i32 = @intCast(tableidx * 16 + 8);

    try buf.appendSlice(allocator, inst.encMovR64FromMemDisp32(.rax, abi.runtime_ptr_save_gpr, jit_abi.tables_ptr_off).slice());

    const result_v = next_vreg.*;
    next_vreg.* += 1;
    if (result_v >= alloc.slots.len) return Error.SlotOverflow;
    const dst_r = try gpr.gprDefSpilled(alloc, result_v, 0);

    // MOV Rdst_d, [RAX + len_disp] (32-bit, zero-ext to 64).
    try buf.appendSlice(allocator, inst.encMovR32FromMemDisp32(dst_r, .rax, len_disp).slice());
    try gpr.gprStoreSpilled(allocator, buf, alloc, spill_base_off, result_v, 0);
    try pushed_vregs.append(allocator, result_v);
}

/// Wasm spec §4.4.14 (table.fill x) — pop n (i32), val (reftype),
/// dst (i32); write `n` copies of `val` into `tables[x][dst..dst+n]`.
/// Traps `OutOfBoundsTableAccess` if `dst+n > tables[x].len`.
///
/// Holder regs after Step A:
///   RDX = dst (zero-ext u32),
///   R8  = val (full 64-bit ref),
///   R10 = n   (zero-ext u32, used as loop counter).
pub fn emitTableFill(
    allocator: Allocator,
    buf: *std.ArrayList(u8),
    alloc: regalloc.Allocation,
    pushed_vregs: *std.ArrayList(u32),
    bounds_fixups: *std.ArrayList(u32),
    spill_base_off: u32,
    func_idx: u32,
    tableidx: u32,
) Error!void {
    if (tableidx >= 1024) return Error.UnsupportedOp;
    const tbl_disp: i32 = @intCast(tableidx * 16);

    if (pushed_vregs.items.len < 3) return Error.AllocationMissing;
    const n_v = pushed_vregs.pop().?;
    const val_v = pushed_vregs.pop().?;
    const dst_v = pushed_vregs.pop().?;

    // Step A: capture operands into private holders. The x86_64
    // allocatable pool {RBX, R12, R13, R14} is disjoint from the
    // {RAX, RCX, RDX, R8, R9, R10, R11} scratch we use here, so
    // this snapshot pass is technically unnecessary for safety;
    // doing it explicitly mirrors the arm64 path's invariant.
    const dst_r = try gpr.gprLoadSpilled(allocator, buf, alloc, spill_base_off, dst_v, 0);
    try buf.appendSlice(allocator, inst.encMovRR(.d, .rdx, dst_r).slice());
    const val_r = try gpr.gprLoadSpilled(allocator, buf, alloc, spill_base_off, val_v, 1);
    try buf.appendSlice(allocator, inst.encMovRR(.q, .r8, val_r).slice());
    const n_r = try gpr.gprLoadSpilled(allocator, buf, alloc, spill_base_off, n_v, 0);
    try buf.appendSlice(allocator, inst.encMovRR(.d, .r10, n_r).slice());

    // Step B: read TableSlice[tableidx]. RAX = tables_ptr; R11 = refs;
    // R9d = len (using R9 since R10/R11/RDX/R8 are already in use).
    try buf.appendSlice(allocator, inst.encMovR64FromMemDisp32(.rax, abi.runtime_ptr_save_gpr, jit_abi.tables_ptr_off).slice());
    try buf.appendSlice(allocator, inst.encMovR64FromMemDisp32(.r11, .rax, tbl_disp).slice());
    try buf.appendSlice(allocator, inst.encMovR32FromMemDisp32(.r9, .rax, tbl_disp + 8).slice());

    // Step C: bounds check — RAX = dst + n; CMP RAX, R9; JA trap.
    //   MOV  RAX, RDX
    //   ADD  RAX, R10
    //   CMP  RAX, R9
    //   JA   trap_stub
    try buf.appendSlice(allocator, inst.encMovRR(.q, .rax, .rdx).slice());
    try buf.appendSlice(allocator, inst.encAddRR(.q, .rax, .r10).slice());
    try buf.appendSlice(allocator, inst.encCmpRR(.q, .rax, .r9).slice());
    {
        const fixup_at: u32 = @intCast(buf.items.len);
        try buf.appendSlice(allocator, inst.encJccRel32(.a, 0).slice());
        try bounds_fixups.append(allocator, fixup_at);
        trace.writeBounds(func_idx, fixup_at);
    }

    // Step D: if n == 0, skip the loop. TEST R10, R10 ; JE end.
    try buf.appendSlice(allocator, inst.encTestRR(.q, .r10, .r10).slice());
    const skip_at: u32 = @intCast(buf.items.len);
    try buf.appendSlice(allocator, inst.encJccRel32(.e, 0).slice());

    // Step E: loop body.
    //   .loop:
    //     MOV [R11 + RDX*8], R8       ; refs[dst] = val (8-byte)
    //     ADD RDX, 1                   ; dst++
    //     ADD R10, -1                  ; n--
    //     JNE .loop
    const loop_start: u32 = @intCast(buf.items.len);
    try buf.appendSlice(allocator, inst_mem.encStoreR64MemBaseIdxLsl3(.r8, .r11, .rdx).slice());
    try buf.appendSlice(allocator, inst.encAddR64Imm32(.rdx, 1).slice());
    try buf.appendSlice(allocator, inst.encAddR64Imm32(.r10, -1).slice());
    {
        const after_jne: i32 = @as(i32, @intCast(buf.items.len)) + 6;
        const disp: i32 = @as(i32, @intCast(loop_start)) - after_jne;
        try buf.appendSlice(allocator, inst.encJccRel32(.ne, disp).slice());
    }

    // Step F: patch the skip JE target.
    const end_byte: u32 = @intCast(buf.items.len);
    const skip_disp: i32 = @as(i32, @intCast(end_byte)) - (@as(i32, @intCast(skip_at)) + 6);
    const patch_enc = inst.encJccRel32(.e, skip_disp);
    @memcpy(buf.items[skip_at..][0..6], patch_enc.slice()[0..6]);
}
