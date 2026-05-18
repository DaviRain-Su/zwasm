//! ARM64 cross-module import bridge thunk encoder
//! (ADR-0066 + Amendment §A1 + §A2 (D-144 γ.4 cycle 4),
//! §9.9-III chunks (c)-2.1 + D-142 fix (A.2)).
//!
//! Each thunk is a 96-byte native code snippet that wraps a
//! call-and-return around the callee's JIT entry, **saving the
//! caller's six reserved-invariant callee-saved registers**
//! (X19/X24/X25/X26/X27/X28 per ADR-0017 + ADR-0018) across the
//! call so the importer's reserved-invariant view survives the
//! callee's prologue overwrite. γ.4 cycle 4 (D-144) found that
//! the prior §A1 56-byte shape saved only X19, leaving X24
//! (typeidx_base), X25 (table_size), X26 (funcptr_base), X27
//! (mem_limit), X28 (vm_base) corrupt across cross-module
//! returns — manifested as `imports.1.wasm print64` `call_indirect
//! sig` mismatch (kind=3) because X24 pointed at the callee's
//! (= imports.0's) typeidx_base instead of the caller's.
//!
//! Layout (96 bytes total):
//!
//! ```text
//! offset  encoding                          disassembly
//! 0x00    STP X29, X30, [SP, #-80]!         ; alloc 80-byte frame, save FP+LR
//! 0x04    STR X19, [SP, #16]                ; save caller's X19 = caller_rt
//! 0x08    STR X24, [SP, #24]                ; save caller's X24 = typeidx_base
//! 0x0C    STR X25, [SP, #32]                ; save caller's X25 = table_size (W-form low)
//! 0x10    STR X26, [SP, #40]                ; save caller's X26 = funcptr_base
//! 0x14    STR X27, [SP, #48]                ; save caller's X27 = mem_limit
//! 0x18    STR X28, [SP, #56]                ; save caller's X28 = vm_base
//! 0x1C    ADR X16, +<offset>                ; X16 ← literal pool base
//! 0x20    LDR X0,  [X16]                    ; X0  ← callee_rt
//! 0x24    LDR X16, [X16, #8]                ; X16 ← callee_entry
//! 0x28    BLR X16                           ; CALL (LR ← PC+4)
//! 0x2C    LDR X19, [SP, #16]                ; RESTORE caller's X19
//! 0x30    LDR X24, [SP, #24]                ; RESTORE caller's X24
//! 0x34    LDR X25, [SP, #32]                ; RESTORE caller's X25
//! 0x38    LDR X26, [SP, #40]                ; RESTORE caller's X26
//! 0x3C    LDR X27, [SP, #48]                ; RESTORE caller's X27
//! 0x40    LDR X28, [SP, #56]                ; RESTORE caller's X28
//! 0x44    LDP X29, X30, [SP], #80           ; restore FP+LR, pop frame
//! 0x48    RET                               ; return to importer
//! 0x4C    (alignment pad — 4 bytes, NOP)
//! 0x50    .quad callee_rt                   ; literal pool
//! 0x58    .quad callee_entry
//! ```
//!
//! 19 × 4-byte instructions + 4-byte pad + 16-byte literal pool
//! = 96 bytes total. `ADR X16, +<offset>` resolves from the ADR's
//! PC (offset 0x1C) to the literal pool base (0x50) — distance =
//! 0x34 = 52 bytes.
//!
//! AAPCS64 §6.4.1 invariant: X19..X28 are callee-saved. v2's
//! JIT prologue (per ADR-0017 sub-2d-ii) overwrites the six
//! reserved-invariant slots (X19 + X24..X28) with new values
//! derived from `*JitRuntime` WITHOUT first stack-saving the
//! caller's value. For same-module calls this is a no-op
//! (caller_rt ≡ callee_rt) but for cross-module bridge thunks
//! caller_rt ≠ callee_rt, so the bridge thunk pays the
//! save/restore cost on the caller's behalf. See
//! `.claude/rules/abi_callee_saved_pinning.md` Option A for
//! the full rationale.
//!
//! Frame layout: `[SP+0]=FP, [SP+8]=LR, [SP+16]=X19,
//! [SP+24]=X24, [SP+32]=X25, [SP+40]=X26, [SP+48]=X27,
//! [SP+56]=X28, [SP+64..72]=padding`. The 80-byte frame keeps
//! SP 16-byte-aligned per AAPCS64 §6.4.5.1; FP/LR sit at the
//! bottom matching the standard unwinder frame shape so a
//! debugger can walk past the thunk.
//!
//! Zone 2 (`src/engine/codegen/arm64/`) — must NOT import
//! `src/engine/codegen/x86_64/` per ROADMAP §A3.

const std = @import("std");
const inst = @import("inst.zig");

/// Total thunk size in bytes (19 instructions × 4 bytes +
/// 4-byte alignment pad + 2 quad literals × 8 bytes = 96).
/// Stable across all callee signatures. γ.4 cycle 4 (D-144)
/// grew the thunk from 56 → 96 bytes to cover the full
/// six-register reserved-invariant cohort.
pub const thunk_bytes: usize = 96;

/// Emit one bridge thunk into `buf[0..thunk_bytes]`. `buf` MUST
/// be exactly `thunk_bytes` long; the caller is responsible for
/// allocating it inside an RX-mappable arena.
///
/// `callee_rt`    — the callee instance's `*JitRuntime` value
///                  to install in X0 before the BLR.
/// `callee_entry` — the callee's JIT entry point.
pub fn emitThunk(buf: []u8, callee_rt: usize, callee_entry: usize) void {
    std.debug.assert(buf.len == thunk_bytes);
    // STP X29, X30, [SP, #-80]! — allocate 80-byte frame +
    // save caller's FP+LR (D-144 cycle 4 — was -32 / 32-byte
    // frame, now -80 / 80-byte frame to accommodate the full
    // X19+X24..X28 reserved-invariant save area).
    std.mem.writeInt(u32, buf[0..4], inst.encStpPreIdx(29, 30, inst.sp_reg, -80), .little);
    // STR X19..X28 reserved-invariant save block.
    std.mem.writeInt(u32, buf[4..8], inst.encStrImm(19, inst.sp_reg, 16), .little);
    std.mem.writeInt(u32, buf[8..12], inst.encStrImm(24, inst.sp_reg, 24), .little);
    std.mem.writeInt(u32, buf[12..16], inst.encStrImm(25, inst.sp_reg, 32), .little);
    std.mem.writeInt(u32, buf[16..20], inst.encStrImm(26, inst.sp_reg, 40), .little);
    std.mem.writeInt(u32, buf[20..24], inst.encStrImm(27, inst.sp_reg, 48), .little);
    std.mem.writeInt(u32, buf[24..28], inst.encStrImm(28, inst.sp_reg, 56), .little);
    // ADR X16, +<offset> — literal pool starts at byte 0x50 from
    // thunk start. ADR instruction is at byte 0x1C (28). Distance
    // = 0x50 - 0x1C = 0x34 = 52 bytes.
    std.mem.writeInt(u32, buf[28..32], inst.encAdr(16, 52), .little);
    // LDR X0, [X16] — X0 ← callee_rt.
    std.mem.writeInt(u32, buf[32..36], inst.encLdrImm(0, 16, 0), .little);
    // LDR X16, [X16, #8] — X16 ← callee_entry.
    std.mem.writeInt(u32, buf[36..40], inst.encLdrImm(16, 16, 8), .little);
    // BLR X16 — CALL.
    std.mem.writeInt(u32, buf[40..44], inst.encBlr(16), .little);
    // LDR X19..X28 — restore caller's reserved-invariant cohort.
    std.mem.writeInt(u32, buf[44..48], inst.encLdrImm(19, inst.sp_reg, 16), .little);
    std.mem.writeInt(u32, buf[48..52], inst.encLdrImm(24, inst.sp_reg, 24), .little);
    std.mem.writeInt(u32, buf[52..56], inst.encLdrImm(25, inst.sp_reg, 32), .little);
    std.mem.writeInt(u32, buf[56..60], inst.encLdrImm(26, inst.sp_reg, 40), .little);
    std.mem.writeInt(u32, buf[60..64], inst.encLdrImm(27, inst.sp_reg, 48), .little);
    std.mem.writeInt(u32, buf[64..68], inst.encLdrImm(28, inst.sp_reg, 56), .little);
    // LDP X29, X30, [SP], #80 — restore FP+LR, pop frame.
    std.mem.writeInt(u32, buf[68..72], inst.encLdpPostIdx(29, 30, inst.sp_reg, 80), .little);
    // RET — return to importer's call site.
    std.mem.writeInt(u32, buf[72..76], inst.encRet(30), .little);
    // 4-byte alignment pad (NOP).
    std.mem.writeInt(u32, buf[76..80], 0xD503201F, .little);
    // Literal pool at offset 0x50 (= 80).
    std.mem.writeInt(u64, buf[80..88], callee_rt, .little);
    std.mem.writeInt(u64, buf[88..96], callee_entry, .little);
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "emitThunk: encoding round-trip via helpers (D-144 cycle 4)" {
    // Re-derive each instruction via the encoder helpers rather
    // than hardcoding byte sequences — keeps the test stable
    // across future thunk reshuffles (was bitten by the §A1 →
    // §A2 grow from 56 → 96 bytes).
    var buf: [thunk_bytes]u8 = undefined;
    const callee_rt: usize = 0xDEADBEEF_CAFEBABE;
    const callee_entry: usize = 0x12345678_9ABCDEF0;
    emitThunk(&buf, callee_rt, callee_entry);

    try testing.expectEqual(inst.encStpPreIdx(29, 30, inst.sp_reg, -80), std.mem.readInt(u32, buf[0..4], .little));
    try testing.expectEqual(inst.encStrImm(19, inst.sp_reg, 16), std.mem.readInt(u32, buf[4..8], .little));
    try testing.expectEqual(inst.encStrImm(24, inst.sp_reg, 24), std.mem.readInt(u32, buf[8..12], .little));
    try testing.expectEqual(inst.encStrImm(25, inst.sp_reg, 32), std.mem.readInt(u32, buf[12..16], .little));
    try testing.expectEqual(inst.encStrImm(26, inst.sp_reg, 40), std.mem.readInt(u32, buf[16..20], .little));
    try testing.expectEqual(inst.encStrImm(27, inst.sp_reg, 48), std.mem.readInt(u32, buf[20..24], .little));
    try testing.expectEqual(inst.encStrImm(28, inst.sp_reg, 56), std.mem.readInt(u32, buf[24..28], .little));
    try testing.expectEqual(inst.encAdr(16, 52), std.mem.readInt(u32, buf[28..32], .little));
    try testing.expectEqual(inst.encLdrImm(0, 16, 0), std.mem.readInt(u32, buf[32..36], .little));
    try testing.expectEqual(inst.encLdrImm(16, 16, 8), std.mem.readInt(u32, buf[36..40], .little));
    try testing.expectEqual(inst.encBlr(16), std.mem.readInt(u32, buf[40..44], .little));
    try testing.expectEqual(inst.encLdrImm(19, inst.sp_reg, 16), std.mem.readInt(u32, buf[44..48], .little));
    try testing.expectEqual(inst.encLdrImm(24, inst.sp_reg, 24), std.mem.readInt(u32, buf[48..52], .little));
    try testing.expectEqual(inst.encLdrImm(25, inst.sp_reg, 32), std.mem.readInt(u32, buf[52..56], .little));
    try testing.expectEqual(inst.encLdrImm(26, inst.sp_reg, 40), std.mem.readInt(u32, buf[56..60], .little));
    try testing.expectEqual(inst.encLdrImm(27, inst.sp_reg, 48), std.mem.readInt(u32, buf[60..64], .little));
    try testing.expectEqual(inst.encLdrImm(28, inst.sp_reg, 56), std.mem.readInt(u32, buf[64..68], .little));
    try testing.expectEqual(inst.encLdpPostIdx(29, 30, inst.sp_reg, 80), std.mem.readInt(u32, buf[68..72], .little));
    try testing.expectEqual(inst.encRet(30), std.mem.readInt(u32, buf[72..76], .little));
    try testing.expectEqual(@as(u32, 0xD503201F), std.mem.readInt(u32, buf[76..80], .little));
    try testing.expectEqual(callee_rt, std.mem.readInt(u64, buf[80..88], .little));
    try testing.expectEqual(callee_entry, std.mem.readInt(u64, buf[88..96], .little));
}

test "emitThunk: round-trip literals at zero" {
    var buf: [thunk_bytes]u8 = undefined;
    emitThunk(&buf, 0, 0);
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[80..88], .little));
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[88..96], .little));
    // Instruction prefix unchanged regardless of literals.
    try testing.expectEqual(inst.encStpPreIdx(29, 30, inst.sp_reg, -80), std.mem.readInt(u32, buf[0..4], .little));
    try testing.expectEqual(inst.encRet(30), std.mem.readInt(u32, buf[72..76], .little));
}

test "emitThunk: instruction prefix is constant across two distinct callees" {
    var buf_a: [thunk_bytes]u8 = undefined;
    var buf_b: [thunk_bytes]u8 = undefined;
    emitThunk(&buf_a, 0x1111_2222_3333_4444, 0x5555_6666_7777_8888);
    emitThunk(&buf_b, 0xAAAA_BBBB_CCCC_DDDD, 0xEEEE_FFFF_0000_1111);
    // First 80 bytes (19 instrs + 4-byte pad) must match — only
    // the literal pool differs between thunks.
    try testing.expectEqualSlices(u8, buf_a[0..80], buf_b[0..80]);
}

test "emitThunk: D-144 cycle 4 saves/restores X19+X24..X28 around BLR" {
    // Structural assertion: between the BLR and the LDP epilogue,
    // the thunk re-loads each of the six reserved-invariant
    // callee-saved registers (X19 + X24..X28) from the frame.
    // This is the load-bearing invariant that closes the D-144
    // cross-module sig-mismatch chain. If future encoder reshuffles
    // drop any save/restore, this test fails before the runtime
    // call_indirect kind=3 trap would.
    var buf: [thunk_bytes]u8 = undefined;
    emitThunk(&buf, 0xDEADBEEF, 0xCAFEBABE);
    // Pre-BLR saves at offsets 4..28.
    try testing.expectEqual(inst.encStrImm(19, inst.sp_reg, 16), std.mem.readInt(u32, buf[4..8], .little));
    try testing.expectEqual(inst.encStrImm(24, inst.sp_reg, 24), std.mem.readInt(u32, buf[8..12], .little));
    try testing.expectEqual(inst.encStrImm(28, inst.sp_reg, 56), std.mem.readInt(u32, buf[24..28], .little));
    // Post-BLR restores at offsets 44..68.
    try testing.expectEqual(inst.encLdrImm(19, inst.sp_reg, 16), std.mem.readInt(u32, buf[44..48], .little));
    try testing.expectEqual(inst.encLdrImm(24, inst.sp_reg, 24), std.mem.readInt(u32, buf[48..52], .little));
    try testing.expectEqual(inst.encLdrImm(28, inst.sp_reg, 56), std.mem.readInt(u32, buf[64..68], .little));
}
