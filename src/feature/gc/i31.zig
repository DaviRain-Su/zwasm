//! i31 small-integer packing for WasmGC (Wasm 3.0 GC proposal).
//!
//! Per ADR-0116 D4: i31 values share the `anyref` / `eqref` u32
//! encoding with heap GcRefs via a low-bit discriminant. Low bit
//! `1` marks an i31; low bit `0` marks a heap pointer (or null
//! when value `== 0`). The 31-bit signed payload occupies the
//! upper bits and is recovered via arithmetic-shift sign-extend.
//!
//! Encoding: `i31_payload = (i32_value << 1) | 1`.
//! Decoding (signed):   `i32_value = (i31_payload >> 1)` (arith).
//! Decoding (unsigned): `i32_value = (i31_payload >> 1) & 0x7FFFFFFF`.
//!
//! Range: `[-2^30, 2^30 - 1]` (signed 31-bit). Values outside
//! this range cannot be packed into an i31 — `i32ToI31` returns
//! `null` (the validator side rejects ahead of runtime per the
//! GC proposal's static typing, but the runtime helper stays
//! defensive for fuzz / host-API call paths).
//!
//! Heap GcRefs comptime-assert ≥ 2-byte alignment (ADR-0115 D5);
//! this preserves the low-bit-0 invariant so the discriminant
//! check is unambiguous.
//!
//! Zone 1 (`src/feature/gc/`).

const std = @import("std");

/// Returns true when the GcRef-encoded `v` holds a small-integer
/// (i31) payload rather than a heap pointer / null. Heap pointers
/// have low bit 0 (alignment invariant); i31 has low bit 1.
pub fn isI31(v: u32) bool {
    return (v & 1) == 1;
}

/// Decode an i31-packed `v` as a signed i32. Sign-extends bit 30
/// up to bit 31 via arithmetic shift. Caller MUST verify
/// `isI31(v)` first (or use this only after a validator-confirmed
/// `i31ref` source); calling on a heap pointer silently mangles
/// the bits.
///
/// Wasm spec 3.0 §3.3.x (GC i31.get_s).
pub fn i31ToI32Signed(v: u32) i32 {
    return @as(i32, @bitCast(v)) >> 1;
}

/// Decode an i31-packed `v` as an unsigned i32. Equivalent to the
/// signed decode followed by masking off the sign bit — the
/// 31-bit payload zero-extends into a 32-bit unsigned.
///
/// Wasm spec 3.0 §3.3.x (GC i31.get_u).
pub fn i31ToI32Unsigned(v: u32) u32 {
    return (v >> 1) & 0x7FFF_FFFF;
}

/// Pack a signed i32 `x` into an i31 GcRef encoding. Returns
/// `null` when `x` is out of the 31-bit signed range
/// `[-2^30, 2^30 - 1]`. The packed value carries low-bit-1 as
/// discriminant; the validator-side gate ensures runtime entries
/// to this function always succeed under spec semantics. The
/// `null` return is retained for fuzz / host-API defence.
///
/// Wasm spec 3.0 §3.3.x (GC ref.i31): the spec's `ref.i31` takes
/// any i32; per ADR-0116 D4 our wider-than-31-bit case mirrors
/// wasmtime / SpiderMonkey's silent low-31-bit truncation. The
/// `null` return-shape is the safer default; callers that want
/// truncation use `i32ToI31Truncate`.
pub fn i32ToI31(x: i32) ?u32 {
    const lo: i32 = std.math.minInt(i32) >> 1; // -2^30
    const hi: i32 = std.math.maxInt(i32) >> 1; //  2^30 - 1
    if (x < lo or x > hi) return null;
    return @as(u32, @bitCast(x << 1)) | 1;
}

/// Truncate-and-pack variant matching the spec's `ref.i31`
/// semantics: keep the low 31 bits of `x` and pack with the
/// discriminant. Always succeeds. Use this for the actual
/// `ref.i31` interp handler.
pub fn i32ToI31Truncate(x: i32) u32 {
    return @as(u32, @bitCast(x << 1)) | 1;
}

const testing = std.testing;

test "isI31: low-bit-1 → true; low-bit-0 → false" {
    try testing.expect(isI31(1));
    try testing.expect(isI31(3));
    try testing.expect(!isI31(0));
    try testing.expect(!isI31(2));
    try testing.expect(!isI31(0xFFFF_FFFE));
    try testing.expect(isI31(0xFFFF_FFFF));
}

test "i32ToI31 + i31ToI32Signed: positive round-trip" {
    const packed_val = i32ToI31(42).?;
    try testing.expect(isI31(packed_val));
    try testing.expectEqual(@as(i32, 42), i31ToI32Signed(packed_val));
}

test "i32ToI31 + i31ToI32Signed: negative round-trip (sign-extend)" {
    const packed_val = i32ToI31(-1).?;
    try testing.expect(isI31(packed_val));
    try testing.expectEqual(@as(i32, -1), i31ToI32Signed(packed_val));

    const packed_min = i32ToI31(-1_073_741_824).?; // -2^30
    try testing.expectEqual(@as(i32, -1_073_741_824), i31ToI32Signed(packed_min));
}

test "i32ToI31 + i31ToI32Signed: at the boundaries" {
    const max_signed: i32 = 1_073_741_823; // 2^30 - 1
    const min_signed: i32 = -1_073_741_824; // -2^30
    try testing.expectEqual(max_signed, i31ToI32Signed(i32ToI31(max_signed).?));
    try testing.expectEqual(min_signed, i31ToI32Signed(i32ToI31(min_signed).?));
}

test "i32ToI31: out-of-range returns null" {
    try testing.expectEqual(@as(?u32, null), i32ToI31(1_073_741_824)); // 2^30
    try testing.expectEqual(@as(?u32, null), i32ToI31(-1_073_741_825)); // -(2^30 + 1)
    try testing.expectEqual(@as(?u32, null), i32ToI31(std.math.maxInt(i32)));
    try testing.expectEqual(@as(?u32, null), i32ToI31(std.math.minInt(i32)));
}

test "i32ToI31Truncate: keeps low 31 bits + always succeeds" {
    // The high bit gets shifted off; bit-30 ends up as the sign bit
    // of the recovered i32.
    const v = i32ToI31Truncate(std.math.maxInt(i32)); // 0x7FFFFFFF
    try testing.expect(isI31(v));
    // Low 31 bits of 0x7FFFFFFF = 0x7FFFFFFF; after << 1 | 1 it's
    // 0xFFFFFFFF. Signed decode: 0xFFFFFFFF >> 1 (arith) = -1.
    try testing.expectEqual(@as(i32, -1), i31ToI32Signed(v));
}

test "i31ToI32Unsigned: high bit always zero" {
    const packed_neg = i32ToI31(-1).?;
    // Signed read sees -1; unsigned read masks off the sign bit.
    try testing.expectEqual(@as(i32, -1), i31ToI32Signed(packed_neg));
    try testing.expectEqual(@as(u32, 0x7FFF_FFFF), i31ToI32Unsigned(packed_neg));
}
