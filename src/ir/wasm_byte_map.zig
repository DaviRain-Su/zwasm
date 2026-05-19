//! Wasm bytecode (`u8` opcode) → ZirOp tag mapping.
//!
//! §9.12-B / B7 transitional helper. The canonical extraction point is
//! `src/ir/lower.zig`'s master `switch (op)` (B8), which IS the byte
//! → ZirOp mapping today (each arm calls `self.emit(.<zir_op>, ...)`).
//!
//! At B7 this file covers only a small set of ops — enough to wire the
//! validator dispatcher path (`src/validate/validator.zig`) through
//! `dispatch_collector.dispatcher(.validate)` for the migrated ops.
//! As §9.12-B per-op handler migrations land (B9..Bn), additional
//! bytes get rows here. The B8 chunk eventually re-extracts this from
//! the lower.zig switch arms as a single comptime table.
//!
//! Returns null for unmapped bytes — the validator's caller falls
//! through to the legacy switch in that case.
//!
//! Per ADR-0073 + `.dev/dispatcher_wire_design.md` §2.1 (option B —
//! "Validator computes ZirOp on the fly via byte→ZirOp helper").
//!
//! Zone 1 (`src/ir/`).

const zir = @import("zir.zig");
const ZirOp = zir.ZirOp;

/// Translate a Wasm bytecode opcode (`u8`) into the corresponding
/// `ZirOp` tag. Returns null for opcodes not yet covered by the
/// transitional map; callers fall through to their legacy dispatch.
///
/// Authoritative source: WebAssembly Core Specification §5.4.X tables.
/// The full mapping is currently embedded in `src/ir/lower.zig`'s
/// `switch (op)`; B8 extracts that wholesale.
pub fn byteToZirOp(byte: u8) ?ZirOp {
    return switch (byte) {
        // Wasm Core 1.0 §5.4.5 — numeric: i32 binary ops.
        // (Coverage extends incrementally as per-op handler bodies
        // migrate in B9..Bn; this initial set proves the wire-in
        // shape and exercises the i32.add per-op file landed in B1.)
        0x6A => .@"i32.add",
        0x6B => .@"i32.sub",
        0x6C => .@"i32.mul",

        // All other bytes: not yet mapped → caller's legacy switch
        // retains authority.
        else => null,
    };
}

const std = @import("std");

test "byteToZirOp maps i32.add (0x6A)" {
    try std.testing.expectEqual(ZirOp.@"i32.add", byteToZirOp(0x6A).?);
}

test "byteToZirOp returns null for unmapped bytes (legacy path)" {
    try std.testing.expectEqual(@as(?ZirOp, null), byteToZirOp(0x00)); // unreachable
    try std.testing.expectEqual(@as(?ZirOp, null), byteToZirOp(0xFF)); // unused space
}
