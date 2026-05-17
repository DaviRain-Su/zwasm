//! ARM64 cross-module import bridge thunk encoder
//! (ADR-0066 + Amendment §A1, §9.9-III chunks (c)-2.1 + D-142
//! fix (A.2)).
//!
//! Each thunk is a 56-byte native code snippet that wraps a
//! call-and-return around the callee's JIT entry, **saving the
//! caller's X19** (`runtime_ptr_save_gpr` per ADR-0017 sub-2d-ii)
//! across the call so the importer's runtime-ptr survives the
//! callee's prologue overwrite. Replaces the original 32-byte
//! tail-call shape (per ADR-0066 Amendment §A1 — see
//! `.dev/lessons/2026-05-17-gamma3d-dispatch-write-segv-bisect.md`
//! for the D-142 root cause chain).
//!
//! Layout:
//!
//! ```text
//! offset  encoding                      disassembly
//! 0x00    STP X29, X30, [SP, #-32]!     ; allocate 32-byte frame, save FP+LR
//! 0x04    STR X19, [SP, #16]            ; save caller's X19 = caller_rt
//! 0x08    ADR X16, .+32                 ; X16 ← literal pool base
//! 0x0C    LDR X0,  [X16]                ; X0  ← callee_rt
//! 0x10    LDR X16, [X16, #8]            ; X16 ← callee_entry
//! 0x14    BLR X16                       ; CALL (LR ← PC+4)
//! 0x18    LDR X19, [SP, #16]            ; RESTORE caller's X19
//! 0x1C    LDP X29, X30, [SP], #32       ; restore FP+LR, pop frame
//! 0x20    RET                           ; return to importer
//! 0x24    (alignment pad — 4 bytes)
//! 0x28    .quad callee_rt               ; literal pool
//! 0x30    .quad callee_entry
//! ```
//!
//! 9 × 4-byte instructions + 4-byte pad + 16-byte literal pool
//! = 56 bytes total. `ADR X16, +32` resolves from the ADR's PC
//! (offset 0x08) to the literal pool base (0x28) — distance =
//! 0x20 = 32 bytes.
//!
//! AAPCS64 §6.4.1 invariant: X19..X28 are callee-saved. v2's
//! JIT prologue (per ADR-0017 sub-2d-ii) overwrites X19 with
//! the new `*JitRuntime` argument WITHOUT first stack-saving
//! the caller's value. For same-module calls this is a no-op
//! (caller_rt ≡ callee_rt) but for cross-module bridge thunks
//! caller_rt ≠ callee_rt, so the bridge thunk pays the
//! save/restore cost on the caller's behalf. See
//! `.claude/rules/abi_callee_saved_pinning.md` Option A for
//! the full rationale.
//!
//! Frame layout: `[SP+0] = prev FP, [SP+8] = prev LR,
//! [SP+16] = saved X19, [SP+24] = unused (alignment)`. The 32-
//! byte frame keeps SP 16-byte-aligned per AAPCS64 §6.4.5.1;
//! FP/LR sit at the bottom matching the standard unwinder frame
//! shape so a debugger can walk past the thunk.
//!
//! Zone 2 (`src/engine/codegen/arm64/`) — must NOT import
//! `src/engine/codegen/x86_64/` per ROADMAP §A3.

const std = @import("std");
const inst = @import("inst.zig");

/// Total thunk size in bytes (9 instructions × 4 bytes +
/// 4-byte alignment pad + 2 quad literals × 8 bytes = 56).
/// Stable across all callee signatures.
pub const thunk_bytes: usize = 56;

/// Emit one bridge thunk into `buf[0..thunk_bytes]`. `buf` MUST
/// be exactly `thunk_bytes` long; the caller is responsible for
/// allocating it inside an RX-mappable arena.
///
/// `callee_rt`    — the callee instance's `*JitRuntime` value
///                  to install in X0 before the BLR.
/// `callee_entry` — the callee's JIT entry point.
pub fn emitThunk(buf: []u8, callee_rt: usize, callee_entry: usize) void {
    std.debug.assert(buf.len == thunk_bytes);
    // STP X29, X30, [SP, #-32]! — allocate 32-byte frame +
    // save caller's FP+LR.
    std.mem.writeInt(u32, buf[0..4], inst.encStpPreIdx(29, 30, inst.sp_reg, -32), .little);
    // STR X19, [SP, #16] — save caller's X19 = caller_rt.
    std.mem.writeInt(u32, buf[4..8], inst.encStrImm(19, inst.sp_reg, 16), .little);
    // ADR X16, +32 — literal pool starts 32 bytes after the
    // ADR instruction (= offset 0x28 from thunk start).
    std.mem.writeInt(u32, buf[8..12], inst.encAdr(16, 32), .little);
    // LDR X0, [X16] — X0 ← *(X16 + 0) = callee_rt.
    std.mem.writeInt(u32, buf[12..16], inst.encLdrImm(0, 16, 0), .little);
    // LDR X16, [X16, #8] — X16 ← *(X16 + 8) = callee_entry.
    std.mem.writeInt(u32, buf[16..20], inst.encLdrImm(16, 16, 8), .little);
    // BLR X16 — CALL (LR ← PC+4); not BR — we need the callee
    // to return here so we can restore X19 before returning to
    // the importer.
    std.mem.writeInt(u32, buf[20..24], inst.encBlr(16), .little);
    // LDR X19, [SP, #16] — RESTORE caller's X19.
    std.mem.writeInt(u32, buf[24..28], inst.encLdrImm(19, inst.sp_reg, 16), .little);
    // LDP X29, X30, [SP], #32 — restore FP+LR, pop frame.
    std.mem.writeInt(u32, buf[28..32], inst.encLdpPostIdx(29, 30, inst.sp_reg, 32), .little);
    // RET — return to importer's call site (LR holds the
    // importer's post-BLR PC saved at the thunk entry).
    std.mem.writeInt(u32, buf[32..36], inst.encRet(30), .little);
    // 4-byte alignment pad so the literal pool starts at an
    // 8-byte-aligned offset. NOP-shaped (0xD503201F = NOP)
    // chosen so a stray jump here is at least benign.
    std.mem.writeInt(u32, buf[36..40], 0xD503201F, .little);
    // Literal pool.
    std.mem.writeInt(u64, buf[40..48], callee_rt, .little);
    std.mem.writeInt(u64, buf[48..56], callee_entry, .little);
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "emitThunk: byte-exact layout for known constants (D-142 A.2)" {
    var buf: [thunk_bytes]u8 = undefined;
    const callee_rt: usize = 0xDEADBEEF_CAFEBABE;
    const callee_entry: usize = 0x12345678_9ABCDEF0;
    emitThunk(&buf, callee_rt, callee_entry);

    // STP X29, X30, [SP, #-32]! — pre-indexed, imm7 = -32/8 = -4
    // Encoding 0xA9BE7BFD: 1010 1001 1011 1110 0111 1011 1111 1101
    //   base 0xA9800000 (STP 64-bit pre-indexed) | imm7=0x7C<<15
    //   | Rt2=30<<10 | Rn=31<<5 | Rt=29
    try testing.expectEqual(@as(u32, 0xA9BE7BFD), std.mem.readInt(u32, buf[0..4], .little));
    // STR X19, [SP, #16] — base 0xF9000000 | imm12=(16>>3)=2<<10
    //   | Rn=31<<5 | Rt=19 = 0xF9000BF3
    try testing.expectEqual(@as(u32, 0xF9000BF3), std.mem.readInt(u32, buf[4..8], .little));
    // ADR X16, +32 — base 0x10000000 | immlo=(32&3)=0<<29
    //   | immhi=(32>>2)=8<<5 | Rd=16 = 0x10000110
    try testing.expectEqual(@as(u32, 0x10000110), std.mem.readInt(u32, buf[8..12], .little));
    // LDR X0, [X16] = 0xF9400200
    try testing.expectEqual(@as(u32, 0xF9400200), std.mem.readInt(u32, buf[12..16], .little));
    // LDR X16, [X16, #8] = 0xF9400610
    try testing.expectEqual(@as(u32, 0xF9400610), std.mem.readInt(u32, buf[16..20], .little));
    // BLR X16 — base 0xD63F0000 | Rn=16<<5 = 0xD63F0200
    try testing.expectEqual(@as(u32, 0xD63F0200), std.mem.readInt(u32, buf[20..24], .little));
    // LDR X19, [SP, #16] — base 0xF9400000 | imm12=2<<10
    //   | Rn=31<<5 | Rt=19 = 0xF9400BF3
    try testing.expectEqual(@as(u32, 0xF9400BF3), std.mem.readInt(u32, buf[24..28], .little));
    // LDP X29, X30, [SP], #32 — post-indexed, imm7 = +4
    //   base 0xA8C00000 (LDP 64-bit post-indexed) | imm7=4<<15
    //   | Rt2=30<<10 | Rn=31<<5 | Rt=29 = 0xA8C27BFD
    try testing.expectEqual(@as(u32, 0xA8C27BFD), std.mem.readInt(u32, buf[28..32], .little));
    // RET X30 — base 0xD65F0000 | Rn=30<<5 = 0xD65F03C0
    try testing.expectEqual(@as(u32, 0xD65F03C0), std.mem.readInt(u32, buf[32..36], .little));
    // NOP padding
    try testing.expectEqual(@as(u32, 0xD503201F), std.mem.readInt(u32, buf[36..40], .little));
    // Literal pool.
    try testing.expectEqual(callee_rt, std.mem.readInt(u64, buf[40..48], .little));
    try testing.expectEqual(callee_entry, std.mem.readInt(u64, buf[48..56], .little));
}

test "emitThunk: round-trip literals at zero" {
    var buf: [thunk_bytes]u8 = undefined;
    emitThunk(&buf, 0, 0);
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[40..48], .little));
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[48..56], .little));
    // Instruction prefix unchanged regardless of literals.
    try testing.expectEqual(@as(u32, 0xA9BE7BFD), std.mem.readInt(u32, buf[0..4], .little));
    try testing.expectEqual(@as(u32, 0xD65F03C0), std.mem.readInt(u32, buf[32..36], .little));
}

test "emitThunk: instruction prefix is constant across two distinct callees" {
    var buf_a: [thunk_bytes]u8 = undefined;
    var buf_b: [thunk_bytes]u8 = undefined;
    emitThunk(&buf_a, 0x1111_2222_3333_4444, 0x5555_6666_7777_8888);
    emitThunk(&buf_b, 0xAAAA_BBBB_CCCC_DDDD, 0xEEEE_FFFF_0000_1111);
    // First 40 bytes (9 instrs + 4-byte pad) must match — only
    // the literal pool differs between thunks (ADR-0066 §A1
    // invariant: instruction prefix is opcode-pinned).
    try testing.expectEqualSlices(u8, buf_a[0..40], buf_b[0..40]);
}

test "emitThunk: D-142 fix (A.2) saves/restores X19 around BLR" {
    // Structural assertion: between the BLR and the RET, the
    // thunk re-loads X19 from [SP, #16]. This is the load-bearing
    // invariant that closes the D-142 X19-corruption chain. If
    // future encoder reshuffles drop the save/restore pair, this
    // test fails before the runtime SEGV would.
    var buf: [thunk_bytes]u8 = undefined;
    emitThunk(&buf, 0xDEADBEEF, 0xCAFEBABE);
    // Pre-BLR: STR X19, [SP, #16] at offset 4..8.
    try testing.expectEqual(@as(u32, 0xF9000BF3), std.mem.readInt(u32, buf[4..8], .little));
    // Post-BLR: LDR X19, [SP, #16] at offset 24..28.
    try testing.expectEqual(@as(u32, 0xF9400BF3), std.mem.readInt(u32, buf[24..28], .little));
}
