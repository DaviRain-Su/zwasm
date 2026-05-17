//! ARM64 cross-module import bridge thunk encoder (ADR-0066,
//! §9.9-III chunk (c)-2.1).
//!
//! Each thunk is a 32-byte native code snippet whose purpose is
//! to swap the JitRuntime pointer (X0) from the importer's to
//! the callee's, then tail-jump to the callee's JIT entry.
//! Layout:
//!
//! ```text
//! offset  encoding         disassembly
//! 0x00    0x10000090       ADR  X16, .+16        ; X16 ← literal pool base
//! 0x04    0xF9400200       LDR  X0,  [X16]       ; X0  ← callee_rt
//! 0x08    0xF9400610       LDR  X16, [X16, #8]   ; X16 ← callee_entry
//! 0x0C    0xD61F0200       BR   X16              ; tail-jump
//! 0x10    .quad callee_rt
//! 0x18    .quad callee_entry
//! ```
//!
//! Tail-call semantics: the importer's BL pushed LR before
//! entering `host_dispatch_base[idx]`. The thunk preserves LR
//! through the BR (BR does not modify LR), so the callee's
//! eventual RET pops the importer's PC and returns directly
//! to the importer's call site. Return value sits in the
//! callee's-ABI return register (X0/V0..V7 per AAPCS64 §6.8),
//! which the importer's `captureCallResult` reads per the
//! callee's signature — identical convention to a same-module
//! call.
//!
//! See ADR-0066 §Decision for the full byte-layout rationale
//! and §"D-138 root cause" for the failure mode this design
//! addresses.
//!
//! Zone 2 (`src/engine/codegen/arm64/`) — must NOT import
//! `src/engine/codegen/x86_64/` per ROADMAP §A3.

const std = @import("std");
const inst = @import("inst.zig");

/// Total thunk size in bytes (4 instructions × 4 bytes + 2
/// quad literals × 8 bytes). Stable across all callee
/// signatures — every thunk has the same shape, only the
/// embedded literals differ.
pub const thunk_bytes: usize = 32;

/// Emit one bridge thunk into `buf[0..thunk_bytes]`. `buf` must
/// be exactly `thunk_bytes` long; the caller is responsible for
/// allocating it inside an RX-mappable arena.
///
/// `callee_rt`    — the callee instance's `*JitRuntime` value
///                  to install in X0 before the tail-jump.
/// `callee_entry` — the callee's JIT entry point (the function
///                  body's first instruction address).
///
/// The literal-pool base is reached via `ADR X16, +16` —
/// since the thunk is exactly 16 bytes of instructions, the
/// literals always start at offset 0x10 from the ADR (the
/// first instruction). PC-relative addressing in AAPCS64 is
/// position-independent, so the thunk can be relocated to any
/// 4-byte-aligned RX page without patching.
pub fn emitThunk(buf: []u8, callee_rt: usize, callee_entry: usize) void {
    std.debug.assert(buf.len == thunk_bytes);
    // ADR X16, +16 — literal pool starts 16 bytes after the
    // first instruction (i.e. immediately after the 4 instrs).
    std.mem.writeInt(u32, buf[0..4], inst.encAdr(16, 16), .little);
    // LDR X0, [X16] — X0 ← *(X16 + 0) = callee_rt.
    std.mem.writeInt(u32, buf[4..8], inst.encLdrImm(0, 16, 0), .little);
    // LDR X16, [X16, #8] — X16 ← *(X16 + 8) = callee_entry.
    std.mem.writeInt(u32, buf[8..12], inst.encLdrImm(16, 16, 8), .little);
    // BR X16 — tail-jump; LR untouched so callee's RET returns
    // to the importer's call site.
    std.mem.writeInt(u32, buf[12..16], inst.encBr(16), .little);
    // Literal pool.
    std.mem.writeInt(u64, buf[16..24], callee_rt, .little);
    std.mem.writeInt(u64, buf[24..32], callee_entry, .little);
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

    // ADR X16, +16 → 0x10000090 (LE bytes: 90 00 00 10)
    try testing.expectEqualSlices(u8, &.{ 0x90, 0x00, 0x00, 0x10 }, buf[0..4]);
    // LDR X0, [X16] → 0xF9400200 (LE: 00 02 40 F9)
    try testing.expectEqualSlices(u8, &.{ 0x00, 0x02, 0x40, 0xF9 }, buf[4..8]);
    // LDR X16, [X16, #8] → 0xF9400610 (LE: 10 06 40 F9)
    try testing.expectEqualSlices(u8, &.{ 0x10, 0x06, 0x40, 0xF9 }, buf[8..12]);
    // BR X16 → 0xD61F0200 (LE: 00 02 1F D6)
    try testing.expectEqualSlices(u8, &.{ 0x00, 0x02, 0x1F, 0xD6 }, buf[12..16]);
    // callee_rt LE
    try testing.expectEqual(callee_rt, std.mem.readInt(u64, buf[16..24], .little));
    // callee_entry LE
    try testing.expectEqual(callee_entry, std.mem.readInt(u64, buf[24..32], .little));
}

test "emitThunk: round-trip literals at zero" {
    var buf: [thunk_bytes]u8 = undefined;
    emitThunk(&buf, 0, 0);
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[16..24], .little));
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, buf[24..32], .little));
    // Instruction prefix unchanged regardless of literals.
    try testing.expectEqual(@as(u32, 0x10000090), std.mem.readInt(u32, buf[0..4], .little));
    try testing.expectEqual(@as(u32, 0xD61F0200), std.mem.readInt(u32, buf[12..16], .little));
}

test "emitThunk: instruction prefix is constant across two distinct callees" {
    var buf_a: [thunk_bytes]u8 = undefined;
    var buf_b: [thunk_bytes]u8 = undefined;
    emitThunk(&buf_a, 0x1111_2222_3333_4444, 0x5555_6666_7777_8888);
    emitThunk(&buf_b, 0xAAAA_BBBB_CCCC_DDDD, 0xEEEE_FFFF_0000_1111);
    // First 16 bytes (4 instructions) must match — only the
    // literal pool differs between thunks (ADR-0066 §Decision
    // invariant: instruction prefix is opcode-pinned).
    try testing.expectEqualSlices(u8, buf_a[0..16], buf_b[0..16]);
}
