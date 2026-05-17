//! Cross-module import bridge thunk facade (ADR-0066, §9.9-III
//! chunk (c)-2.1). Arch-agnostic API; routes to `arm64/thunk.zig`
//! or `x86_64/thunk.zig` per `builtin.target.cpu.arch` (same
//! pattern as `shared/compile.zig`'s emit-module switch).
//!
//! A bridge thunk is the per-import-resolved native-code snippet
//! planted into `JitRuntime.host_dispatch_base[i]` when import
//! `i` resolves against a registered exporter Wasm instance.
//! At call time the importer's emit path performs the standard
//! indirect-call sequence (caller-side emit unchanged); the
//! thunk swaps the JitRuntime pointer from caller's to
//! callee's and tail-jumps to the callee's JIT entry. The
//! callee's eventual RET returns directly to the importer's
//! call site; the importer's `captureCallResult` reads the
//! return register per the callee's signature.
//!
//! See ADR-0066 §Decision for the byte-layout rationale across
//! both architectures and §Consequences §"Implementation chunk
//! plan" for the (c)-2.2..(c)-2.4 sequence that consumes this
//! facade.
//!
//! Zone 2 (`src/engine/codegen/shared/`) — may import both
//! arch modules per the established `shared/` cross-arch
//! pattern (cf. `shared/compile.zig:42`).

const std = @import("std");
const builtin = @import("builtin");

const arch_thunk = switch (builtin.target.cpu.arch) {
    .aarch64 => @import("../arm64/thunk.zig"),
    .x86_64 => @import("../x86_64/thunk.zig"),
    else => @compileError("ADR-0066 bridge thunk encoder not implemented for this architecture"),
};

/// Bridge thunk byte count for the current target architecture.
/// 32 bytes on AArch64 (4 instructions + 16-byte literal pool);
/// 22 bytes on x86_64 (3 instructions, literals embedded in
/// MOV imm64). Stable across all callee signatures — every
/// thunk has the same shape; only the embedded literals differ.
pub const thunk_bytes: usize = arch_thunk.thunk_bytes;

/// Emit one bridge thunk into `buf[0..thunk_bytes]`. `buf` MUST
/// be exactly `thunk_bytes` long for the current target. The
/// caller owns the buffer and is responsible for placing it in
/// an RX-mappable arena before the thunk is invoked (see
/// (c)-2.2 thunk-arena lifecycle chunk).
///
/// `callee_rt`    — the callee instance's `*JitRuntime` cast to
///                  `usize` (the address that will be installed
///                  in the runtime-ptr register before the
///                  tail-jump: X0 on AArch64, RDI on x86_64).
/// `callee_entry` — the callee's JIT entry point address (the
///                  first instruction of the callee function's
///                  body in its module's JIT code block).
///
/// The emitted thunk is position-independent on both targets
/// (AArch64 uses PC-relative ADR; x86_64 embeds the literals
/// in MOV imm64), so it can be relocated to any RX page
/// without patching after emit.
pub fn emitThunk(buf: []u8, callee_rt: usize, callee_entry: usize) void {
    arch_thunk.emitThunk(buf, callee_rt, callee_entry);
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "thunk_bytes: matches arch-specific constant" {
    switch (builtin.target.cpu.arch) {
        .aarch64 => try testing.expectEqual(@as(usize, 32), thunk_bytes),
        .x86_64 => try testing.expectEqual(@as(usize, 22), thunk_bytes),
        else => return error.SkipZigTest,
    }
}

test "emitThunk: writes exactly thunk_bytes bytes (no over/under-fill)" {
    // Allocate one extra byte at each end pre-filled with a
    // sentinel; verify the emit doesn't touch either.
    const guard_byte: u8 = 0xAA;
    var buf: [thunk_bytes + 2]u8 = undefined;
    @memset(&buf, guard_byte);
    emitThunk(buf[1 .. 1 + thunk_bytes], 0x1234_5678_9ABC_DEF0, 0xFEDC_BA98_7654_3210);
    try testing.expectEqual(guard_byte, buf[0]);
    try testing.expectEqual(guard_byte, buf[buf.len - 1]);
}

test "emitThunk: distinct callee pairs produce distinct thunks" {
    var a: [thunk_bytes]u8 = undefined;
    var b: [thunk_bytes]u8 = undefined;
    emitThunk(&a, 0x1, 0x2);
    emitThunk(&b, 0x3, 0x4);
    try testing.expect(!std.mem.eql(u8, &a, &b));
}
