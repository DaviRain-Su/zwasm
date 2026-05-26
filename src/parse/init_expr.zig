//! Wasm constant-expression machinery (Wasm spec §5.4.1 init
//! expressions + §5.3.1 valtype encoding). Consumed by section
//! decoders (globals, elements, data) inside `sections.zig` and
//! by the per-section siblings (`sections_element.zig`,
//! `sections_codes.zig`, `sections_data.zig`).
//!
//! Extracted per ADR-0101 (post-ADR-0099 redesign) as a deep
//! utility — the previous ADR-0095 / ADR-0096 sibling extractions
//! created helper-circular imports back into `sections.zig`. This
//! module is consumed one-way; nothing inside it imports
//! `sections.zig`.

const std = @import("std");

const leb128 = @import("../support/leb128.zig");
const zir = @import("../ir/zir.zig");

const ValType = zir.ValType;

/// Strict subset of `sections.Error`. Zig's narrow-error-set
/// inference converts `init_expr.Error` to `sections.Error`
/// implicitly when section decoders propagate via `try`.
pub const Error = error{
    UnexpectedEnd,
    InvalidFunctype,
    BadValType,
} || leb128.Error;

/// Wasm spec §5.4.1 — advance `pos.*` past a constant expression
/// (init expression), stopping after the terminating `0x0B` byte.
///
/// Replacing the prior naive byte-scan for 0x0B is mandatory: the
/// `v128.const` immediate is raw bytes and can legally contain 0x0B
/// (case study: simd_const.388.wasm — a global's v128.const lane
/// byte 11 = 0x0B caused the next global's globaltype byte to be
/// read inside the lane data → BadValType).
pub fn scanInitExpr(body: []const u8, pos: *usize) Error!void {
    while (true) {
        if (pos.* >= body.len) return Error.UnexpectedEnd;
        const op = body[pos.*];
        pos.* += 1;
        switch (op) {
            0x0B => return,
            0x41 => try skipLeb128(body, pos, 5), // i32.const (sleb128)
            0x42 => try skipLeb128(body, pos, 10), // i64.const (sleb128)
            0x43 => { // f32.const
                if (pos.* + 4 > body.len) return Error.UnexpectedEnd;
                pos.* += 4;
            },
            0x44 => { // f64.const
                if (pos.* + 8 > body.len) return Error.UnexpectedEnd;
                pos.* += 8;
            },
            0x23 => _ = try leb128.readUleb128(u32, body, pos), // global.get
            0xD0 => { // ref.null reftype
                if (pos.* >= body.len) return Error.UnexpectedEnd;
                pos.* += 1;
            },
            0xD2 => _ = try leb128.readUleb128(u32, body, pos), // ref.func
            0xFD => { // SIMD prefix — only v128.const (0x0C) is constant
                const sub = try leb128.readUleb128(u32, body, pos);
                if (sub != 0x0C) return Error.InvalidFunctype;
                if (pos.* + 16 > body.len) return Error.UnexpectedEnd;
                pos.* += 16;
            },
            else => return Error.InvalidFunctype,
        }
    }
}

/// Advance `pos.*` past a LEB128 byte sequence (signed or unsigned).
/// Only the continuation bits are inspected; the value is discarded.
fn skipLeb128(body: []const u8, pos: *usize, comptime max_bytes: usize) Error!void {
    var i: usize = 0;
    while (i < max_bytes) : (i += 1) {
        if (pos.* >= body.len) return Error.UnexpectedEnd;
        const byte = body[pos.*];
        pos.* += 1;
        if ((byte & 0x80) == 0) return;
    }
    return Error.InvalidFunctype;
}

/// Wasm spec §5.3.1 (valtype) — `valtype ::= numtype | vectype | reftype`
/// where `numtype ∈ {i32, i64, f32, f64}`, `vectype = v128`, and
/// `reftype ∈ {funcref, externref}`.
pub fn readValType(body: []const u8, pos: *usize) Error!ValType {
    if (pos.* >= body.len) return Error.UnexpectedEnd;
    const b = body[pos.*];
    pos.* += 1;
    return switch (b) {
        0x7F => .i32,
        0x7E => .i64,
        0x7D => .f32,
        0x7C => .f64,
        0x7B => .v128, // Wasm 2.0 SIMD §5.3.5
        0x70 => .funcref, // Wasm 2.0 §5.3.1 reftype
        0x6F => .externref, // Wasm 2.0 §5.3.1 reftype
        // Wasm 3.0 GC §5.3.1 heap-top reftype bytes
        // (10.G op_gc cycles 3 + 6).
        0x6E => .anyref,
        0x6D => .eqref,
        0x6C => .i31ref,
        0x6B => .structref,
        0x6A => .arrayref,
        else => Error.BadValType,
    };
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "scanInitExpr: i32.const 0; end" {
    const body = [_]u8{ 0x41, 0x00, 0x0B };
    var pos: usize = 0;
    try scanInitExpr(&body, &pos);
    try testing.expectEqual(@as(usize, 3), pos);
}

test "scanInitExpr: v128.const containing 0x0B lane byte does not terminate early" {
    // FD 0C <16 bytes including 0x0B>; then 0x0B end.
    const body = [_]u8{
        0xFD, 0x0C,
        0x00, 0x01,
        0x02, 0x03,
        0x04, 0x05,
        0x06, 0x07,
        0x08, 0x09, 0x0A, 0x0B, // 0x0B as raw lane byte, MUST be skipped
        0x0C, 0x0D, 0x0E, 0x0F,
        0x0B, // real end
    };
    var pos: usize = 0;
    try scanInitExpr(&body, &pos);
    try testing.expectEqual(body.len, pos);
}

test "readValType: i32 / v128 / funcref" {
    {
        var pos: usize = 0;
        const body = [_]u8{0x7F};
        try testing.expectEqual(ValType.i32, try readValType(&body, &pos));
    }
    {
        var pos: usize = 0;
        const body = [_]u8{0x7B};
        try testing.expectEqual(ValType.v128, try readValType(&body, &pos));
    }
    {
        var pos: usize = 0;
        const body = [_]u8{0x70};
        try testing.expectEqual(ValType.funcref, try readValType(&body, &pos));
    }
}

test "readValType: BadValType on unknown encoding" {
    var pos: usize = 0;
    const body = [_]u8{0x00};
    try testing.expectError(Error.BadValType, readValType(&body, &pos));
}

test "readValType: i31ref (Wasm 3.0 GC byte 0x6C; 10.G op_gc cycle 3)" {
    // Wasm 3.0 GC spec §5.3.1 — i31ref valtype encoding byte.
    // Cycle 3 of 10.G-op_gc bundle.
    var pos: usize = 0;
    const body = [_]u8{0x6C};
    try testing.expectEqual(ValType.i31ref, try readValType(&body, &pos));
    try testing.expectEqual(@as(usize, 1), pos);
}

test "readValType: anyref/eqref/structref/arrayref (Wasm 3.0 GC; 10.G op_gc cycle 6)" {
    // Wasm 3.0 GC spec §5.3.1 — remaining heap-top reftype bytes.
    // Pins the cycle-6 ValType enum extension + parser arm-out.
    {
        var pos: usize = 0;
        const body = [_]u8{0x6E};
        try testing.expectEqual(ValType.anyref, try readValType(&body, &pos));
    }
    {
        var pos: usize = 0;
        const body = [_]u8{0x6D};
        try testing.expectEqual(ValType.eqref, try readValType(&body, &pos));
    }
    {
        var pos: usize = 0;
        const body = [_]u8{0x6B};
        try testing.expectEqual(ValType.structref, try readValType(&body, &pos));
    }
    {
        var pos: usize = 0;
        const body = [_]u8{0x6A};
        try testing.expectEqual(ValType.arrayref, try readValType(&body, &pos));
    }
}
