//! x86_64 emit handler for `array.new` — Wasm 3.0 GC §3.3.5.6.6.
//! Mirror of the arm64 handler: pop i32 length (top) + init value,
//! allocate + fill via the `jitGcAllocArrayFill(rt, typeidx, length,
//! init)` trampoline (runtime element count → fill inside the trampoline,
//! not an emitted loop), push the GcRef. Both operands consumed into arg
//! regs BEFORE the CALL (length → EDX, init → RCX) → strict `is_call`.
//!
//! NOTE: init marshaled from a GPR (`MOV RCX, Rinit`) — GPR element types
//! only (f32/f64 deferred; see debt). SysV args RDI/ESI/EDX/RCX; ret EAX.
//! Intel SDM Vol.2 (MOV 0x89, MOVABS 0xB8, CALL 0xFF /2).

const meta = @import("../../../../../instruction/wasm_3_0/array_new.zig");
const ctx_mod = @import("../../ctx.zig");
const abi = @import("../../abi.zig");
const gpr = @import("../../gpr.zig");
const inst = @import("../../inst.zig");
const jit_abi = @import("../../../shared/jit_abi.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

const call_scratch: abi.Gpr = .r10; // emit scratch — &fn, then CALL target.

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    const typeidx: u32 = @intCast(ins.payload);
    const args = try ctx.popBinary(); // lhs=init, rhs=length (top), result=ref
    // EDX = length (rhs); RCX = init (lhs, full 8-byte value bits).
    const xsize = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.rhs, 0);
    if (xsize != .rdx) try ctx.buf.appendSlice(ctx.allocator, inst.encMovRR(.d, .rdx, xsize).slice());
    const xinit = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.lhs, 1);
    if (xinit != .rcx) try ctx.buf.appendSlice(ctx.allocator, inst.encMovRR(.q, .rcx, xinit).slice());
    // RDI = rt (R15); ESI = typeidx.
    try ctx.buf.appendSlice(ctx.allocator, inst.encMovRR(.q, .rdi, abi.runtime_ptr_save_gpr).slice());
    try ctx.buf.appendSlice(ctx.allocator, inst.encMovImm32W(.rsi, typeidx).slice());
    // MOVABS R10 = &jitGcAllocArrayFill; CALL R10.
    const addr: u64 = @intFromPtr(&jit_abi.jitGcAllocArrayFill);
    try ctx.buf.appendSlice(ctx.allocator, inst.encMovImm64Q(call_scratch, addr).slice());
    try ctx.buf.appendSlice(ctx.allocator, inst.encCallReg(call_scratch).slice());

    // Capture EAX (GcRef) → result vreg.
    const rd = try gpr.gprDefSpilled(ctx.alloc, args.result, 0);
    if (rd != .rax) try ctx.buf.appendSlice(ctx.allocator, inst.encMovRR(.d, rd, .rax).slice());
    try gpr.gprStoreSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, args.result, 0);
    try ctx.pushed_vregs.append(ctx.allocator, args.result);
}
