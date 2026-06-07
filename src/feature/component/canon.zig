//! Canonical ABI **CanonContext + flat-scalar lift/lower** (CM campaign chunk
//! B1; spec `component-model/design/mvp/CanonicalABI.md`). Design: ADR-0171.
//!
//! Lifts/lowers component-level values across the core/component boundary. A
//! component `Value` is DISTINCT from `runtime.Value` (`single_slot_dual_meaning`):
//! it carries interface semantics (a `char` is a Unicode scalar). The
//! *flattened* lowered form, however, IS `runtime.Value` — that is what the
//! core invoke receives. So `lower: Value -> runtime.Value` and
//! `lift: runtime.Value -> Value`.
//!
//! B1 covers the flat scalar primitives (each flattens to ONE core value, no
//! memory touch). Aggregates (string / list / record / variant) and the
//! size/align/discriminant machinery + flags/enum land in B2+. The
//! `cabi_realloc` callback is scaffolding here, first exercised by B3 (string).
//!
//! The realloc callback is INJECTED (vtable pattern, `zone_deps`): canon.zig
//! never imports the core runtime's instance/invoke; the orchestration layer
//! (B6) installs a callback that runs the guest's `cabi_realloc` export. Only
//! `runtime.Value` (the flattened core value type) is imported here.

const std = @import("std");

const types = @import("types.zig");
const core = @import("../../runtime/value.zig");

const CoreValue = core.Value;
const PrimValType = types.PrimValType;

/// A component-level runtime value. B1: flat scalar primitives only.
pub const Value = union(enum) {
    bool: bool,
    s8: i8,
    u8: u8,
    s16: i16,
    u16: u16,
    s32: i32,
    u32: u32,
    s64: i64,
    u64: u64,
    f32: f32,
    f64: f64,
    char: u21,
};

/// The core wasm type a flat primitive flattens to (`CanonicalABI.md`
/// flattening). Aggregates flatten to a sequence of these (later chunks).
pub const CoreType = enum { i32, i64, f32, f64 };

pub fn flatCoreType(p: PrimValType) ?CoreType {
    return switch (p) {
        .bool, .s8, .u8, .s16, .u16, .s32, .u32, .char => .i32,
        .s64, .u64 => .i64,
        .f32 => .f32,
        .f64 => .f64,
        // string / error-context are aggregate (ptr+len) — not a flat scalar.
        .string, .error_context => null,
    };
}

pub const ReallocError = error{ AllocFailed, OutOfBounds };

/// Spec `cabi_realloc` contract: `(old_ptr, old_size, alignment, new_size) ->
/// new_ptr`. Injected by the orchestration layer (B6) to invoke the guest's
/// `cabi_realloc` export so allocation runs in the guest's own allocator
/// (ADR-0171). An error result signals OOM / trap.
pub const ReallocFn = *const fn (ctx: *anyopaque, old_ptr: u32, old_size: u32, alignment: u32, new_size: u32) ReallocError!u32;

/// Per-call canonical-ABI context: the guest linear memory (lift/lower target)
/// + the injected realloc callback.
pub const CanonContext = struct {
    memory: []u8,
    realloc_ctx: *anyopaque,
    realloc_fn: ReallocFn,

    pub fn realloc(self: CanonContext, old_ptr: u32, old_size: u32, alignment: u32, new_size: u32) ReallocError!u32 {
        return self.realloc_fn(self.realloc_ctx, old_ptr, old_size, alignment, new_size);
    }
};

pub const LiftError = error{
    /// A `char` core value outside the Unicode scalar range (`> 0x10FFFF` or a
    /// surrogate). Strict per-type boundary validation expands in B2.
    InvalidChar,
    /// Lifting an aggregate / non-flat-scalar type — handled in B2+.
    NotFlatScalar,
};

/// Lower a flat-scalar component value to its single core value
/// (`CanonicalABI.md`: signed/unsigned ints zero/sign-extend into i32/i64;
/// bool → 0/1; char → its scalar value).
pub fn lower(value: Value) CoreValue {
    return switch (value) {
        .bool => |b| CoreValue.fromI32(if (b) 1 else 0),
        .s8 => |v| CoreValue.fromI32(v),
        .u8 => |v| CoreValue.fromI32(v),
        .s16 => |v| CoreValue.fromI32(v),
        .u16 => |v| CoreValue.fromI32(v),
        .s32 => |v| CoreValue.fromI32(v),
        .u32 => |v| CoreValue.fromI32(@bitCast(v)),
        .s64 => |v| CoreValue.fromI64(v),
        .u64 => |v| CoreValue.fromI64(@bitCast(v)),
        .f32 => |v| CoreValue{ .f32 = v },
        .f64 => |v| CoreValue{ .f64 = v },
        .char => |v| CoreValue.fromI32(@intCast(v)),
    };
}

/// Lift a single core value back to a flat-scalar component value of type `ty`.
pub fn lift(c: CoreValue, ty: PrimValType) LiftError!Value {
    const i32_bits: u32 = @bitCast(c.i32);
    return switch (ty) {
        .bool => .{ .bool = c.i32 != 0 },
        .s8 => .{ .s8 = @bitCast(@as(u8, @truncate(i32_bits))) },
        .u8 => .{ .u8 = @truncate(i32_bits) },
        .s16 => .{ .s16 = @bitCast(@as(u16, @truncate(i32_bits))) },
        .u16 => .{ .u16 = @truncate(i32_bits) },
        .s32 => .{ .s32 = c.i32 },
        .u32 => .{ .u32 = i32_bits },
        .s64 => .{ .s64 = c.i64 },
        .u64 => .{ .u64 = @bitCast(c.i64) },
        .f32 => .{ .f32 = c.f32 },
        .f64 => .{ .f64 = c.f64 },
        .char => blk: {
            if (i32_bits > 0x10FFFF or (i32_bits >= 0xD800 and i32_bits <= 0xDFFF)) return LiftError.InvalidChar;
            break :blk .{ .char = @intCast(i32_bits) };
        },
        .string, .error_context => LiftError.NotFlatScalar,
    };
}

// ============================================================
// Tests
// ============================================================
const testing = std.testing;

test "round-trip: i32 (s32) through lower/lift" {
    const v = Value{ .s32 = 42 };
    const c = lower(v);
    try testing.expectEqual(@as(i32, 42), c.i32);
    try testing.expectEqual(Value{ .s32 = 42 }, try lift(c, .s32));
}

test "round-trip: every flat scalar primitive" {
    const cases = [_]Value{
        .{ .bool = true }, .{ .bool = false },
        .{ .s8 = -5 },     .{ .u8 = 200 },
        .{ .s16 = -3000 }, .{ .u16 = 60000 },
        .{ .s32 = -1 },    .{ .u32 = 0xFFFF_FFFF },
        .{ .s64 = -9 },    .{ .u64 = 0xFFFF_FFFF_FFFF_FFFF },
        .{ .char = 'A' }, .{ .char = 0x1F600 }, // 😀
    };
    const tys = [_]PrimValType{
        .bool, .bool,
        .s8,   .u8,
        .s16,  .u16,
        .s32,  .u32,
        .s64,  .u64,
        .char, .char,
    };
    for (cases, tys) |v, ty| {
        try testing.expectEqual(v, try lift(lower(v), ty));
    }
}

test "round-trip: floats preserve bits incl. NaN payload" {
    const f32v = Value{ .f32 = 3.5 };
    try testing.expectEqual(f32v, try lift(lower(f32v), .f32));
    const f64v = Value{ .f64 = -2.25 };
    try testing.expectEqual(f64v, try lift(lower(f64v), .f64));
}

test "lift: char out of range / surrogate rejected" {
    try testing.expectError(LiftError.InvalidChar, lift(CoreValue.fromI32(0x110000), .char));
    try testing.expectError(LiftError.InvalidChar, lift(CoreValue.fromI32(0xD800), .char));
}

test "lift: aggregate type is NotFlatScalar in B1" {
    try testing.expectError(LiftError.NotFlatScalar, lift(CoreValue.fromI32(0), .string));
}

test "flatCoreType: primitive flattening shape" {
    try testing.expectEqual(CoreType.i32, flatCoreType(.bool).?);
    try testing.expectEqual(CoreType.i32, flatCoreType(.u32).?);
    try testing.expectEqual(CoreType.i64, flatCoreType(.s64).?);
    try testing.expectEqual(CoreType.f64, flatCoreType(.f64).?);
    try testing.expectEqual(@as(?CoreType, null), flatCoreType(.string));
}

test "CanonContext.realloc delegates to the injected callback" {
    const Mock = struct {
        fn realloc(ctx: *anyopaque, old_ptr: u32, old_size: u32, alignment: u32, new_size: u32) ReallocError!u32 {
            _ = ctx;
            _ = old_ptr;
            _ = old_size;
            _ = alignment;
            // A trivial bump that just echoes new_size as the address.
            return new_size;
        }
    };
    var dummy_mem = [_]u8{0} ** 16;
    var sentinel: u8 = 0;
    const ctx = CanonContext{
        .memory = &dummy_mem,
        .realloc_ctx = @ptrCast(&sentinel),
        .realloc_fn = Mock.realloc,
    };
    try testing.expectEqual(@as(u32, 64), try ctx.realloc(0, 0, 4, 64));
}
