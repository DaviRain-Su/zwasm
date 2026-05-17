//! x86_64 cross-module import bridge thunk encoder (ADR-0066,
//! §9.9-III chunk (c)-2.1).
//!
//! Each thunk is a 22-byte native code snippet whose purpose is
//! to swap the JitRuntime pointer (RDI per System V AMD64 ABI
//! §3.2.3) from the importer's to the callee's, then tail-jump
//! to the callee's JIT entry. Layout:
//!
//! ```text
//! offset  encoding                            disassembly
//! 0x00    48 BF <callee_rt LE 8 bytes>        MOV  RDI, imm64
//! 0x0A    48 B8 <callee_entry LE 8 bytes>     MOV  RAX, imm64
//! 0x14    FF E0                               JMP  RAX
//! ```
//!
//! Tail-call semantics: the importer's CALL pushed the
//! return address before entering `host_dispatch_base[idx]`.
//! The thunk replaces RDI with the callee's JitRuntime and
//! JMPs to the callee's entry — the callee's eventual RET
//! pops the importer's return address and returns directly
//! to the importer's call site. Return value sits in the
//! callee's-ABI return register (RAX / XMM0 / RDX:RAX pair /
//! XMM0:XMM1 pair per SysV §3.2.3), which the importer's
//! `captureCallResult` reads per the callee's signature —
//! identical convention to a same-module call.
//!
//! See ADR-0066 §Decision for the full byte-layout rationale
//! and §"D-138 root cause" for the failure mode this design
//! addresses.
//!
//! Zone 2 (`src/engine/codegen/x86_64/`) — must NOT import
//! `src/engine/codegen/arm64/` per ROADMAP §A3.

const std = @import("std");
const inst = @import("inst.zig");

/// Total thunk size in bytes (10 + 10 + 2 = 22). Stable across
/// all callee signatures.
pub const thunk_bytes: usize = 22;

/// Emit one bridge thunk into `buf[0..thunk_bytes]`. `buf` must
/// be exactly `thunk_bytes` long; the caller is responsible for
/// allocating it inside an RX-mappable arena.
///
/// `callee_rt`    — the callee instance's `*JitRuntime` value
///                  to install in RDI before the tail-jump.
/// `callee_entry` — the callee's JIT entry point (the function
///                  body's first instruction address).
///
/// Both literals are encoded directly into the MOV imm64
/// instructions (no separate literal pool), so the thunk is
/// position-independent: it can be relocated to any byte-aligned
/// RX page without patching.
pub fn emitThunk(buf: []u8, callee_rt: usize, callee_entry: usize) void {
    std.debug.assert(buf.len == thunk_bytes);
    const mov_rdi = inst.encMovImm64Q(.rdi, callee_rt);
    @memcpy(buf[0..mov_rdi.len], mov_rdi.slice());
    const mov_rax = inst.encMovImm64Q(.rax, callee_entry);
    @memcpy(buf[10..20], mov_rax.slice());
    const jmp_rax = inst.encJmpReg(.rax);
    @memcpy(buf[20..22], jmp_rax.slice());
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "emitThunk: byte-exact layout for known constants" {
    var buf: [thunk_bytes]u8 = undefined;
    const callee_rt: usize = 0xDEADBEEF_CAFEBABE;
    const callee_entry: usize = 0x12345678_9ABCDEF0;
    emitThunk(&buf, callee_rt, callee_entry);

    // MOV RDI, callee_rt — REX.W (48) + opcode (B8+rdi.low3=7=BF) + LE imm64
    try testing.expectEqualSlices(u8, &.{
        0x48, 0xBF,
        0xBE, 0xBA,
        0xFE, 0xCA,
        0xEF, 0xBE,
        0xAD, 0xDE,
    }, buf[0..10]);
    // MOV RAX, callee_entry — REX.W (48) + opcode (B8+rax.low3=0=B8) + LE imm64
    try testing.expectEqualSlices(u8, &.{
        0x48, 0xB8,
        0xF0, 0xDE,
        0xBC, 0x9A,
        0x78, 0x56,
        0x34, 0x12,
    }, buf[10..20]);
    // JMP RAX — FF E0
    try testing.expectEqualSlices(u8, &.{ 0xFF, 0xE0 }, buf[20..22]);
}

test "emitThunk: round-trip literals at zero" {
    var buf: [thunk_bytes]u8 = undefined;
    emitThunk(&buf, 0, 0);
    // Opcodes unchanged; both imm64 fields all-zero.
    try testing.expectEqual(@as(u8, 0x48), buf[0]);
    try testing.expectEqual(@as(u8, 0xBF), buf[1]);
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[2..10], .little));
    try testing.expectEqual(@as(u8, 0x48), buf[10]);
    try testing.expectEqual(@as(u8, 0xB8), buf[11]);
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[12..20], .little));
    try testing.expectEqualSlices(u8, &.{ 0xFF, 0xE0 }, buf[20..22]);
}

test "emitThunk: opcode bytes are constant across two distinct callees" {
    var buf_a: [thunk_bytes]u8 = undefined;
    var buf_b: [thunk_bytes]u8 = undefined;
    emitThunk(&buf_a, 0x1111_2222_3333_4444, 0x5555_6666_7777_8888);
    emitThunk(&buf_b, 0xAAAA_BBBB_CCCC_DDDD, 0xEEEE_FFFF_0000_1111);
    // REX.W + opcode + (imm64 slot) — opcodes at fixed offsets
    // 0/1, 10/11, 20/21 must match across thunks (ADR-0066
    // §Decision invariant).
    try testing.expectEqual(buf_a[0], buf_b[0]);
    try testing.expectEqual(buf_a[1], buf_b[1]);
    try testing.expectEqual(buf_a[10], buf_b[10]);
    try testing.expectEqual(buf_a[11], buf_b[11]);
    try testing.expectEqualSlices(u8, buf_a[20..22], buf_b[20..22]);
}
