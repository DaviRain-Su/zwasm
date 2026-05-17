//! x86_64 cross-module import bridge thunk encoder
//! (ADR-0066 + Amendment §A1, §9.9-III chunks (c)-2.1 + D-142
//! fix (A.3)).
//!
//! Each thunk is a 27-byte native code snippet that wraps a
//! call-and-return around the callee's JIT entry, **saving the
//! caller's R15** (`runtime_ptr_save_gpr` per ADR-0026 Cc-pivot)
//! across the CALL so the importer's runtime-ptr survives the
//! callee's prologue overwrite. Mirrors the arm64 A.2 redesign
//! per ADR-0066 §A1 — see
//! `.dev/lessons/2026-05-17-gamma3d-dispatch-write-segv-bisect.md`
//! for the D-142 root cause chain and
//! `.claude/rules/abi_callee_saved_pinning.md` for the
//! cross-instance pinned-reg discipline.
//!
//! Layout:
//!
//! ```text
//! offset  encoding                            disassembly
//! 0x00    41 57                               PUSH R15           ; save caller's R15
//! 0x02    48 BF <callee_rt LE 8 bytes>        MOV  RDI, imm64    ; SysV arg0
//! 0x0C    48 B8 <callee_entry LE 8 bytes>     MOV  RAX, imm64
//! 0x16    FF D0                               CALL RAX           ; SysV CALL (not JMP)
//! 0x18    41 5F                               POP  R15           ; RESTORE caller's R15
//! 0x1A    C3                                  RET                ; return to importer
//! ```
//!
//! 2 + 10 + 10 + 2 + 2 + 1 = 27 bytes total. The literals are
//! embedded directly in the MOV imm64 instructions (no separate
//! pool), so the thunk is position-independent: relocate to any
//! byte-aligned RX page without patching.
//!
//! SysV AMD64 §3.2.1 invariant: RBX, RBP, R12..R15 are callee-
//! saved. v2's JIT prologue (per ADR-0026 Cc-pivot) overwrites
//! R15 with the new `*JitRuntime` argument WITHOUT first
//! stack-saving the caller's value. For same-module calls this
//! is a no-op (caller_rt ≡ callee_rt) but for cross-module
//! bridge thunks caller_rt ≠ callee_rt, so the bridge thunk
//! pays the save/restore cost on the caller's behalf. Same
//! discipline pattern as arm64 X19; see ADR-0066 §A1 for the
//! full Option A rationale (over Option B / C alternatives).
//!
//! Stack-alignment note: SysV requires `RSP % 16 == 0` at the
//! point of CALL (so the called function sees RSP+8 aligned).
//! The importer's CALL into the thunk leaves RSP unaligned
//! (off by 8 due to the pushed return address). The thunk's
//! PUSH R15 restores 16-byte alignment before the CALL RAX —
//! intentional + load-bearing for SSE/AVX instructions in the
//! callee that require aligned SP.
//!
//! Zone 2 (`src/engine/codegen/x86_64/`) — must NOT import
//! `src/engine/codegen/arm64/` per ROADMAP §A3.

const std = @import("std");
const inst = @import("inst.zig");

/// Total thunk size in bytes (PUSH R15 [2] + MOV RDI imm64 [10]
/// + MOV RAX imm64 [10] + CALL RAX [2] + POP R15 [2] + RET [1]
/// = 27). Stable across all callee signatures.
pub const thunk_bytes: usize = 27;

/// Emit one bridge thunk into `buf[0..thunk_bytes]`. `buf` MUST
/// be exactly `thunk_bytes` long; the caller is responsible for
/// allocating it inside an RX-mappable arena.
///
/// `callee_rt`    — the callee instance's `*JitRuntime` value
///                  to install in RDI before the CALL.
/// `callee_entry` — the callee's JIT entry point.
pub fn emitThunk(buf: []u8, callee_rt: usize, callee_entry: usize) void {
    std.debug.assert(buf.len == thunk_bytes);
    // PUSH R15 — save caller's R15 = caller_rt. Also re-aligns
    // RSP to 16 bytes (importer's CALL left it off by 8).
    const push_r15 = inst.encPushR(.r15);
    @memcpy(buf[0..2], push_r15.slice());
    // MOV RDI, callee_rt — SysV arg0 (= *JitRuntime).
    const mov_rdi = inst.encMovImm64Q(.rdi, callee_rt);
    @memcpy(buf[2..12], mov_rdi.slice());
    // MOV RAX, callee_entry.
    const mov_rax = inst.encMovImm64Q(.rax, callee_entry);
    @memcpy(buf[12..22], mov_rax.slice());
    // CALL RAX — SysV CALL (not JMP); pushes post-CALL RIP so
    // the callee's RET returns here, not to the importer. Needed
    // so the thunk can POP R15 + RET below.
    const call_rax = inst.encCallReg(.rax);
    @memcpy(buf[22..24], call_rax.slice());
    // POP R15 — RESTORE caller's R15.
    const pop_r15 = inst.encPopR(.r15);
    @memcpy(buf[24..26], pop_r15.slice());
    // RET — return to importer's call site.
    const ret = inst.encRet();
    @memcpy(buf[26..27], ret.slice());
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "emitThunk: byte-exact layout for known constants (D-142 A.3)" {
    var buf: [thunk_bytes]u8 = undefined;
    const callee_rt: usize = 0xDEADBEEF_CAFEBABE;
    const callee_entry: usize = 0x12345678_9ABCDEF0;
    emitThunk(&buf, callee_rt, callee_entry);

    // PUSH R15 — 0x41 0x57 (REX.B + 50+r15.low3=7)
    try testing.expectEqualSlices(u8, &.{ 0x41, 0x57 }, buf[0..2]);
    // MOV RDI, callee_rt — REX.W (48) + opcode (B8+rdi.low3=7=BF) + LE imm64
    try testing.expectEqualSlices(u8, &.{
        0x48, 0xBF,
        0xBE, 0xBA,
        0xFE, 0xCA,
        0xEF, 0xBE,
        0xAD, 0xDE,
    }, buf[2..12]);
    // MOV RAX, callee_entry — REX.W (48) + opcode (B8+rax.low3=0=B8) + LE imm64
    try testing.expectEqualSlices(u8, &.{
        0x48, 0xB8,
        0xF0, 0xDE,
        0xBC, 0x9A,
        0x78, 0x56,
        0x34, 0x12,
    }, buf[12..22]);
    // CALL RAX — 0xFF 0xD0 (opcode /2 = CALL)
    try testing.expectEqualSlices(u8, &.{ 0xFF, 0xD0 }, buf[22..24]);
    // POP R15 — 0x41 0x5F (REX.B + 58+r15.low3=7)
    try testing.expectEqualSlices(u8, &.{ 0x41, 0x5F }, buf[24..26]);
    // RET — 0xC3
    try testing.expectEqual(@as(u8, 0xC3), buf[26]);
}

test "emitThunk: round-trip literals at zero" {
    var buf: [thunk_bytes]u8 = undefined;
    emitThunk(&buf, 0, 0);
    // Opcodes unchanged; both imm64 fields all-zero.
    try testing.expectEqualSlices(u8, &.{ 0x41, 0x57 }, buf[0..2]);
    try testing.expectEqual(@as(u8, 0x48), buf[2]);
    try testing.expectEqual(@as(u8, 0xBF), buf[3]);
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[4..12], .little));
    try testing.expectEqual(@as(u8, 0x48), buf[12]);
    try testing.expectEqual(@as(u8, 0xB8), buf[13]);
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[14..22], .little));
    try testing.expectEqualSlices(u8, &.{ 0xFF, 0xD0 }, buf[22..24]);
    try testing.expectEqualSlices(u8, &.{ 0x41, 0x5F }, buf[24..26]);
    try testing.expectEqual(@as(u8, 0xC3), buf[26]);
}

test "emitThunk: opcode bytes are constant across two distinct callees" {
    var buf_a: [thunk_bytes]u8 = undefined;
    var buf_b: [thunk_bytes]u8 = undefined;
    emitThunk(&buf_a, 0x1111_2222_3333_4444, 0x5555_6666_7777_8888);
    emitThunk(&buf_b, 0xAAAA_BBBB_CCCC_DDDD, 0xEEEE_FFFF_0000_1111);
    // Frame + opcode bytes at fixed offsets must match across
    // thunks (ADR-0066 §A1 invariant); only the embedded imm64
    // literals differ.
    try testing.expectEqualSlices(u8, buf_a[0..2], buf_b[0..2]); // PUSH R15
    try testing.expectEqualSlices(u8, buf_a[2..4], buf_b[2..4]); // REX.W + MOV RDI opcode
    try testing.expectEqualSlices(u8, buf_a[12..14], buf_b[12..14]); // REX.W + MOV RAX opcode
    try testing.expectEqualSlices(u8, buf_a[22..27], buf_b[22..27]); // CALL + POP + RET
}

test "emitThunk: D-142 fix (A.3) saves/restores R15 around CALL" {
    // Structural assertion: between PUSH R15 (entry) and POP
    // R15 (exit), the thunk does the CALL RAX. This is the
    // load-bearing invariant that closes the D-142
    // R15-corruption chain on x86_64. If future encoder
    // reshuffles drop the PUSH/POP pair, this test fails
    // before the runtime SEGV would.
    var buf: [thunk_bytes]u8 = undefined;
    emitThunk(&buf, 0xDEADBEEF, 0xCAFEBABE);
    try testing.expectEqualSlices(u8, &.{ 0x41, 0x57 }, buf[0..2]); // PUSH R15
    try testing.expectEqualSlices(u8, &.{ 0xFF, 0xD0 }, buf[22..24]); // CALL RAX
    try testing.expectEqualSlices(u8, &.{ 0x41, 0x5F }, buf[24..26]); // POP R15
    try testing.expectEqual(@as(u8, 0xC3), buf[26]); // RET
}
