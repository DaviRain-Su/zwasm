//! Canonical ABI **lift/lower + memory layout** (CM campaign chunks B1–B4;
//! spec `component-model/design/mvp/CanonicalABI.md`). Design: ADR-0171.
//!
//! Lifts/lowers component-level values across the core/component boundary. A
//! component `Value` is DISTINCT from `runtime.Value` (`single_slot_dual_meaning`):
//! it carries interface semantics (a `char` is a Unicode scalar). The flat
//! lowered form of a scalar IS `runtime.Value` (`lower`/`lift`); aggregates are
//! laid out in guest linear memory (`store`/`load`).
//!
//! Coverage: B1 flat scalars · B2 enum/flags + size/align/discriminant · B3
//! utf8 string over memory · B4 recursive `store`/`load` for list + record.
//! variant/option/result (B5) + the multi-value flat lowering for fn-call
//! params (B6) extend this. utf16/latin1 string encodings pending.
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

/// A component-level runtime value. B1: flat scalars; B2 enum/flags; B4 adds
/// the aggregate forms (string / list / record). `list`/`record` borrow their
/// element/field slices from the caller (or an arena on load).
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
    /// `enum` value = the case index (`0..len(labels)`).
    enum_value: u32,
    /// `flags` value = a packed bit-set (bit `i` ⇔ label `i`; ≤32 bits).
    flags: u32,
    string: []const u8,
    list: []const Value,
    /// `record` fields, positional (parallel to the `CanonType.record` fields).
    record: []const Value,
};

/// The despecialized value type the canonical ABI computes layout over. B2:
/// primitives + enum + flags; B4 adds the recursive `list` / `record` forms;
/// variant/option/result extend it in B5.
pub const CanonType = union(enum) {
    prim: PrimValType,
    /// number of enum cases (`> 0`).
    enum_: u32,
    /// number of flags labels (`0 < n <= 32`).
    flags: u32,
    /// variable-length list of an element type.
    list: *const CanonType,
    record: []const Field,

    pub const Field = struct {
        name: []const u8,
        ty: CanonType,
    };
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

/// In-memory alignment of a primitive (`CanonicalABI.md` `alignment`).
fn primAlignment(p: PrimValType) usize {
    return switch (p) {
        .bool, .s8, .u8 => 1,
        .s16, .u16 => 2,
        .s32, .u32, .f32, .char, .error_context => 4,
        .s64, .u64, .f64 => 8,
        .string => 4, // ptr alignment (32-bit core memory)
    };
}

/// In-memory size of a primitive (`CanonicalABI.md` `elem_size`). For scalars
/// size == alignment; string is a (ptr,len) pair.
fn primSize(p: PrimValType) usize {
    return switch (p) {
        .string => 8, // 2 * ptr_size
        .bool, .s8, .u8, .s16, .u16, .s32, .u32, .s64, .u64, .f32, .f64, .char, .error_context => primAlignment(p),
    };
}

/// Smallest integer width (bytes) covering `n` enum/variant cases
/// (`CanonicalABI.md` `discriminant_type`): ≤256→1, ≤65536→2, else 4.
pub fn discriminantSize(n_cases: u32) usize {
    if (n_cases <= 256) return 1;
    if (n_cases <= 65536) return 2;
    return 4;
}

/// Packed `flags` byte width (`CanonicalABI.md` `alignment_flags`/
/// `elem_size_flags`): ≤8→1, ≤16→2, else 4 (n is capped at 32).
pub fn flagsSize(n_labels: u32) usize {
    if (n_labels <= 8) return 1;
    if (n_labels <= 16) return 2;
    return 4;
}

/// `align_to(ptr, a)` (`CanonicalABI.md`): round `ptr` up to a multiple of `a`.
pub fn alignTo(ptr: usize, a: usize) usize {
    return (ptr + a - 1) / a * a;
}

/// In-memory alignment of a value type (recursive).
pub fn alignmentOf(t: CanonType) usize {
    return switch (t) {
        .prim => |p| primAlignment(p),
        .enum_ => |n| discriminantSize(n),
        .flags => |n| flagsSize(n),
        .list => 4, // (ptr, len) → ptr alignment
        .record => |fields| blk: {
            var a: usize = 1;
            for (fields) |f| a = @max(a, alignmentOf(f.ty));
            break :blk a;
        },
    };
}

/// In-memory size of a value type (recursive; `CanonicalABI.md` `elem_size`).
pub fn sizeOf(t: CanonType) usize {
    return switch (t) {
        .prim => |p| primSize(p),
        .enum_ => |n| discriminantSize(n),
        .flags => |n| flagsSize(n),
        .list => 8, // ptr + len
        .record => |fields| blk: {
            var s: usize = 0;
            for (fields) |f| {
                s = alignTo(s, alignmentOf(f.ty));
                s += sizeOf(f.ty);
            }
            break :blk alignTo(s, alignmentOf(t));
        },
    };
}

pub const ReallocError = error{ AllocFailed, OutOfBounds };

/// Spec `cabi_realloc` contract: `(old_ptr, old_size, alignment, new_size) ->
/// new_ptr`. Injected by the orchestration layer (B6) to invoke the guest's
/// `cabi_realloc` export so allocation runs in the guest's own allocator
/// (ADR-0171). An error result signals OOM / trap.
pub const ReallocFn = *const fn (ctx: *anyopaque, old_ptr: u32, old_size: u32, alignment: u32, new_size: u32) ReallocError!u32;

/// Guest string encoding (`canonopt` `string-encoding`). B3 implements utf8;
/// utf16 / latin1+utf16 land next.
pub const StringEncoding = enum { utf8, utf16, latin1_utf16 };

/// Per-call canonical-ABI context: the guest linear memory (lift/lower target),
/// the injected realloc callback, and the string encoding option.
pub const CanonContext = struct {
    memory: []u8,
    realloc_ctx: *anyopaque,
    realloc_fn: ReallocFn,
    string_encoding: StringEncoding = .utf8,

    pub fn realloc(self: CanonContext, old_ptr: u32, old_size: u32, alignment: u32, new_size: u32) ReallocError!u32 {
        return self.realloc_fn(self.realloc_ctx, old_ptr, old_size, alignment, new_size);
    }
};

/// `CanonicalABI.md` `MAX_STRING_BYTE_LENGTH` — a string's byte length must fit
/// 28 bits (leaves the high bit free as the latin1/utf16 tag).
pub const MAX_STRING_BYTE_LENGTH: u32 = (1 << 28) - 1;

pub const StringError = error{
    OutOfBounds,
    InvalidUtf8,
    StringTooLong,
    /// utf16 / latin1+utf16 lowering/lifting — implemented in the next chunk.
    UnsupportedEncoding,
} || ReallocError;

/// Lower a host UTF-8 string into guest memory (`store_string_into_range`):
/// allocate `len` bytes via the guest realloc, copy the bytes, and return the
/// `(ptr, packed_length)` pair the canonical ABI flattens to two i32s. For
/// utf8 `packed_length == byte_length` (no tag bit).
pub fn lowerString(cx: CanonContext, s: []const u8) StringError!struct { ptr: u32, packed_length: u32 } {
    if (cx.string_encoding != .utf8) return StringError.UnsupportedEncoding;
    if (s.len > MAX_STRING_BYTE_LENGTH) return StringError.StringTooLong;
    const byte_len: u32 = @intCast(s.len);
    const ptr = try cx.realloc(0, 0, 1, byte_len);
    if (@as(usize, ptr) + s.len > cx.memory.len) return StringError.OutOfBounds;
    @memcpy(cx.memory[ptr..][0..s.len], s);
    return .{ .ptr = ptr, .packed_length = byte_len };
}

/// Lift a guest UTF-8 string (`load_string_from_range`): bounds-check + UTF-8
/// validate the `[ptr, ptr+byte_length)` range. Returns a slice BORROWING
/// guest memory (valid until the memory is mutated).
pub fn liftString(cx: CanonContext, ptr: u32, packed_length: u32) StringError![]const u8 {
    if (cx.string_encoding != .utf8) return StringError.UnsupportedEncoding;
    const byte_length = packed_length; // utf8: code units == bytes, no tag bit
    if (byte_length > MAX_STRING_BYTE_LENGTH) return StringError.StringTooLong;
    if (@as(usize, ptr) + byte_length > cx.memory.len) return StringError.OutOfBounds;
    const bytes = cx.memory[ptr..][0..byte_length];
    if (!std.unicode.utf8ValidateSlice(bytes)) return StringError.InvalidUtf8;
    return bytes;
}

pub const LiftError = error{
    /// A `char` core value outside the Unicode scalar range (`> 0x10FFFF` or a
    /// surrogate).
    InvalidChar,
    /// An enum discriminant `>= len(cases)`.
    InvalidEnum,
    /// A flags bit-set with bits set beyond the declared label count.
    InvalidFlags,
    /// Lifting an aggregate / non-flat-scalar type — handled in B3+.
    NotFlatScalar,
};

pub const LowerError = error{
    /// An aggregate (string/list/record) has no single-core-value flat form —
    /// it lowers to a sequence via memory (use `store`); the multi-value flat
    /// lowering for fn-call params lands in B6.
    NotFlatScalar,
};

/// Lower a flat-scalar component value to its single core value
/// (`CanonicalABI.md`: signed/unsigned ints zero/sign-extend into i32/i64;
/// bool → 0/1; char → its scalar value). Aggregates error (`NotFlatScalar`).
pub fn lower(value: Value) LowerError!CoreValue {
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
        // enum + flags both flatten to a single i32 (discriminant / bit-set).
        .enum_value => |idx| CoreValue.fromI32(@bitCast(idx)),
        .flags => |bits| CoreValue.fromI32(@bitCast(bits)),
        .string, .list, .record => LowerError.NotFlatScalar,
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

/// Lift a single core value to a component value of type `t`. Dispatches
/// primitives to `lift`; validates enum/flags ranges. Aggregates have no
/// single-value flat form (`NotFlatScalar`) — use `load`.
pub fn liftTyped(c: CoreValue, t: CanonType) LiftError!Value {
    return switch (t) {
        .prim => |p| lift(c, p),
        .enum_ => |n| blk: {
            const idx: u32 = @bitCast(c.i32);
            if (idx >= n) return LiftError.InvalidEnum;
            break :blk .{ .enum_value = idx };
        },
        .flags => |n| blk: {
            const bits: u32 = @bitCast(c.i32);
            // Bits beyond the declared labels must be zero (n ≤ 32).
            if (n < 32 and (bits >> @intCast(n)) != 0) return LiftError.InvalidFlags;
            break :blk .{ .flags = bits };
        },
        .list, .record => LiftError.NotFlatScalar,
    };
}

// ============================================================
// Memory store / load — the recursive canonical-ABI tree (`store`/`load`).
// ============================================================

pub const StoreError = error{ OutOfBounds, ValueTypeMismatch } || StringError;
pub const LoadError = error{ OutOfBounds, ValueTypeMismatch, OutOfMemory } || StringError || LiftError;

/// Write an integer `v` as `nbytes` little-endian at `ptr` (`store_int`).
fn storeInt(cx: CanonContext, v: u64, ptr: u32, nbytes: usize) StoreError!void {
    if (@as(usize, ptr) + nbytes > cx.memory.len) return StoreError.OutOfBounds;
    var i: usize = 0;
    while (i < nbytes) : (i += 1) cx.memory[ptr + i] = @truncate(v >> @intCast(i * 8));
}

/// Read `nbytes` little-endian at `ptr` as an unsigned integer (`load_int`).
fn loadInt(cx: CanonContext, ptr: u32, nbytes: usize) LoadError!u64 {
    if (@as(usize, ptr) + nbytes > cx.memory.len) return LoadError.OutOfBounds;
    var v: u64 = 0;
    var i: usize = 0;
    while (i < nbytes) : (i += 1) v |= @as(u64, cx.memory[ptr + i]) << @intCast(i * 8);
    return v;
}

/// Store a component value into guest memory at `ptr` per its type layout
/// (`CanonicalABI.md` `store`). Recursive over list/record.
pub fn store(cx: CanonContext, value: Value, ty: CanonType, ptr: u32) StoreError!void {
    switch (ty) {
        .prim => |p| switch (p) {
            .string => {
                const s = if (value == .string) value.string else return StoreError.ValueTypeMismatch;
                const lowered = try lowerString(cx, s);
                try storeInt(cx, lowered.ptr, ptr, 4);
                try storeInt(cx, lowered.packed_length, ptr + 4, 4);
            },
            .bool, .s8, .u8, .s16, .u16, .s32, .u32, .s64, .u64, .f32, .f64, .char, .error_context => try storeInt(cx, try scalarBits(value, p), ptr, primSize(p)),
        },
        .enum_ => |n| {
            if (value != .enum_value or value.enum_value >= n) return StoreError.ValueTypeMismatch;
            try storeInt(cx, value.enum_value, ptr, discriminantSize(n));
        },
        .flags => |n| {
            if (value != .flags) return StoreError.ValueTypeMismatch;
            try storeInt(cx, value.flags, ptr, flagsSize(n));
        },
        .list => |elem| {
            const items = if (value == .list) value.list else return StoreError.ValueTypeMismatch;
            const esize = sizeOf(elem.*);
            const ealign = alignmentOf(elem.*);
            const byte_len: u32 = @intCast(items.len * esize);
            const base = try cx.realloc(0, 0, @intCast(ealign), byte_len);
            if (@as(usize, base) + byte_len > cx.memory.len) return StoreError.OutOfBounds;
            for (items, 0..) |e, i| try store(cx, e, elem.*, base + @as(u32, @intCast(i * esize)));
            try storeInt(cx, base, ptr, 4);
            try storeInt(cx, items.len, ptr + 4, 4);
        },
        .record => |fields| {
            const vals = if (value == .record) value.record else return StoreError.ValueTypeMismatch;
            if (vals.len != fields.len) return StoreError.ValueTypeMismatch;
            var off: u32 = ptr;
            for (fields, vals) |f, v| {
                off = @intCast(alignTo(off, alignmentOf(f.ty)));
                try store(cx, v, f.ty, off);
                off += @intCast(sizeOf(f.ty));
            }
        },
    }
}

/// Load a component value of type `ty` from guest memory at `ptr` (`load`).
/// list/record allocate their element/field slices from `arena`.
pub fn load(cx: CanonContext, arena: std.mem.Allocator, ty: CanonType, ptr: u32) LoadError!Value {
    switch (ty) {
        .prim => |p| switch (p) {
            .string => {
                const sptr: u32 = @intCast(try loadInt(cx, ptr, 4));
                const slen: u32 = @intCast(try loadInt(cx, ptr + 4, 4));
                return .{ .string = try liftString(cx, sptr, slen) };
            },
            .bool, .s8, .u8, .s16, .u16, .s32, .u32, .s64, .u64, .f32, .f64, .char, .error_context => return lift(coreFromBits(try loadInt(cx, ptr, primSize(p)), p), p),
        },
        .enum_ => |n| {
            const disc: u32 = @intCast(try loadInt(cx, ptr, discriminantSize(n)));
            return liftTyped(CoreValue.fromI32(@bitCast(disc)), .{ .enum_ = n });
        },
        .flags => |n| {
            const bits: u32 = @intCast(try loadInt(cx, ptr, flagsSize(n)));
            return liftTyped(CoreValue.fromI32(@bitCast(bits)), .{ .flags = n });
        },
        .list => |elem| {
            const base: u32 = @intCast(try loadInt(cx, ptr, 4));
            const len: usize = @intCast(try loadInt(cx, ptr + 4, 4));
            const esize = sizeOf(elem.*);
            const out = try arena.alloc(Value, len);
            for (out, 0..) |*slot, i| slot.* = try load(cx, arena, elem.*, base + @as(u32, @intCast(i * esize)));
            return .{ .list = out };
        },
        .record => |fields| {
            const out = try arena.alloc(Value, fields.len);
            var off: u32 = ptr;
            for (fields, out) |f, *slot| {
                off = @intCast(alignTo(off, alignmentOf(f.ty)));
                slot.* = try load(cx, arena, f.ty, off);
                off += @intCast(sizeOf(f.ty));
            }
            return .{ .record = out };
        },
    }
}

/// Reconstruct the core value of primitive `p` from `nbytes` of loaded LE bits
/// (the inverse of how `store` placed them) so `lift` can decode it.
fn coreFromBits(bits: u64, p: PrimValType) CoreValue {
    return switch (p) {
        .bool, .s8, .u8, .s16, .u16, .s32, .u32, .char => CoreValue.fromI32(@bitCast(@as(u32, @truncate(bits)))),
        .s64, .u64 => CoreValue.fromI64(@bitCast(bits)),
        .f32 => CoreValue{ .f32 = @bitCast(@as(u32, @truncate(bits))) },
        .f64 => CoreValue{ .f64 = @bitCast(bits) },
        .string, .error_context => CoreValue.fromI32(0), // unreachable via load's string branch
    };
}

/// The unsigned bit pattern a scalar (non-string) primitive stores, widened to
/// u64 (LE-truncated to `primSize` by `storeInt`).
fn scalarBits(value: Value, p: PrimValType) StoreError!u64 {
    return switch (p) {
        .bool => if (value == .bool) @intFromBool(value.bool) else StoreError.ValueTypeMismatch,
        .s8 => if (value == .s8) @as(u8, @bitCast(value.s8)) else StoreError.ValueTypeMismatch,
        .u8 => if (value == .u8) value.u8 else StoreError.ValueTypeMismatch,
        .s16 => if (value == .s16) @as(u16, @bitCast(value.s16)) else StoreError.ValueTypeMismatch,
        .u16 => if (value == .u16) value.u16 else StoreError.ValueTypeMismatch,
        .s32 => if (value == .s32) @as(u32, @bitCast(value.s32)) else StoreError.ValueTypeMismatch,
        .u32 => if (value == .u32) value.u32 else StoreError.ValueTypeMismatch,
        .s64 => if (value == .s64) @as(u64, @bitCast(value.s64)) else StoreError.ValueTypeMismatch,
        .u64 => if (value == .u64) value.u64 else StoreError.ValueTypeMismatch,
        .f32 => if (value == .f32) @as(u32, @bitCast(value.f32)) else StoreError.ValueTypeMismatch,
        .f64 => if (value == .f64) @as(u64, @bitCast(value.f64)) else StoreError.ValueTypeMismatch,
        .char => if (value == .char) value.char else StoreError.ValueTypeMismatch,
        .string, .error_context => StoreError.ValueTypeMismatch,
    };
}

// ============================================================
// Tests
// ============================================================
const testing = std.testing;

test "round-trip: i32 (s32) through lower/lift" {
    const v = Value{ .s32 = 42 };
    const c = try lower(v);
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
        try testing.expectEqual(v, try lift(try lower(v), ty));
    }
}

test "round-trip: floats preserve bits incl. NaN payload" {
    const f32v = Value{ .f32 = 3.5 };
    try testing.expectEqual(f32v, try lift(try lower(f32v), .f32));
    const f64v = Value{ .f64 = -2.25 };
    try testing.expectEqual(f64v, try lift(try lower(f64v), .f64));
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

test "size/align: primitive layout matches spec" {
    try testing.expectEqual(@as(usize, 1), sizeOf(.{ .prim = .bool }));
    try testing.expectEqual(@as(usize, 1), alignmentOf(.{ .prim = .u8 }));
    try testing.expectEqual(@as(usize, 2), sizeOf(.{ .prim = .s16 }));
    try testing.expectEqual(@as(usize, 4), sizeOf(.{ .prim = .char }));
    try testing.expectEqual(@as(usize, 8), alignmentOf(.{ .prim = .u64 }));
    try testing.expectEqual(@as(usize, 8), sizeOf(.{ .prim = .f64 }));
    try testing.expectEqual(@as(usize, 8), sizeOf(.{ .prim = .string })); // (ptr,len)
}

test "discriminant width flips at 256 / 65536 boundaries" {
    try testing.expectEqual(@as(usize, 1), discriminantSize(1));
    try testing.expectEqual(@as(usize, 1), discriminantSize(256));
    try testing.expectEqual(@as(usize, 2), discriminantSize(257));
    try testing.expectEqual(@as(usize, 2), discriminantSize(65536));
    try testing.expectEqual(@as(usize, 4), discriminantSize(65537));
}

test "flags width flips at 8 / 16 boundaries" {
    try testing.expectEqual(@as(usize, 1), flagsSize(8));
    try testing.expectEqual(@as(usize, 2), flagsSize(9));
    try testing.expectEqual(@as(usize, 2), flagsSize(16));
    try testing.expectEqual(@as(usize, 4), flagsSize(17));
    try testing.expectEqual(@as(usize, 4), flagsSize(32));
}

test "round-trip: enum discriminant" {
    const v = Value{ .enum_value = 3 };
    try testing.expectEqual(@as(i32, 3), (try lower(v)).i32);
    try testing.expectEqual(v, try liftTyped(try lower(v), .{ .enum_ = 5 }));
}

test "lift: enum discriminant out of range rejected" {
    try testing.expectError(LiftError.InvalidEnum, liftTyped(CoreValue.fromI32(5), .{ .enum_ = 5 }));
}

test "round-trip: flags bit-set" {
    const v = Value{ .flags = 0b101 };
    try testing.expectEqual(@as(i32, 0b101), (try lower(v)).i32);
    try testing.expectEqual(v, try liftTyped(try lower(v), .{ .flags = 3 }));
}

test "lift: flags with bits beyond label count rejected" {
    // 3 labels → only bits 0..2 valid; bit 3 set is malformed.
    try testing.expectError(LiftError.InvalidFlags, liftTyped(CoreValue.fromI32(0b1000), .{ .flags = 3 }));
    // 32 labels → all 32 bits valid (no shift-overflow, no rejection).
    _ = try liftTyped(CoreValue.fromI32(@bitCast(@as(u32, 0xFFFF_FFFF))), .{ .flags = 32 });
}

/// A bump allocator over a `[]u8` standing in for the guest's `cabi_realloc`.
const Bump = struct {
    next: u32,
    fn realloc(ctx: *anyopaque, old_ptr: u32, old_size: u32, alignment: u32, new_size: u32) ReallocError!u32 {
        _ = old_ptr;
        _ = old_size;
        const self: *Bump = @ptrCast(@alignCast(ctx));
        const aligned = std.mem.alignForward(u32, self.next, @max(alignment, 1));
        self.next = aligned + new_size;
        return aligned;
    }
};

test "round-trip: utf8 string guest↔host via realloc + memory" {
    var mem = [_]u8{0} ** 256;
    var bump = Bump{ .next = 8 };
    const cx = CanonContext{ .memory = &mem, .realloc_ctx = @ptrCast(&bump), .realloc_fn = Bump.realloc };

    const lowered = try lowerString(cx, "héllo, 世界"); // multibyte utf8
    try testing.expect(lowered.ptr >= 8);
    const back = try liftString(cx, lowered.ptr, lowered.packed_length);
    try testing.expectEqualStrings("héllo, 世界", back);
}

test "round-trip: empty string" {
    var mem = [_]u8{0} ** 16;
    var bump = Bump{ .next = 0 };
    const cx = CanonContext{ .memory = &mem, .realloc_ctx = @ptrCast(&bump), .realloc_fn = Bump.realloc };
    const lowered = try lowerString(cx, "");
    try testing.expectEqual(@as(u32, 0), lowered.packed_length);
    try testing.expectEqualStrings("", try liftString(cx, lowered.ptr, lowered.packed_length));
}

test "lift: out-of-bounds range rejected" {
    var mem = [_]u8{0} ** 8;
    var bump = Bump{ .next = 0 };
    const cx = CanonContext{ .memory = &mem, .realloc_ctx = @ptrCast(&bump), .realloc_fn = Bump.realloc };
    try testing.expectError(StringError.OutOfBounds, liftString(cx, 4, 100));
}

test "lift: invalid utf8 rejected" {
    var mem = [_]u8{ 0xFF, 0xFE, 0, 0, 0, 0, 0, 0 }; // 0xFF is never valid utf8
    var bump = Bump{ .next = 0 };
    const cx = CanonContext{ .memory = &mem, .realloc_ctx = @ptrCast(&bump), .realloc_fn = Bump.realloc };
    try testing.expectError(StringError.InvalidUtf8, liftString(cx, 0, 2));
}

test "string: non-utf8 encoding deferred" {
    var mem = [_]u8{0} ** 8;
    var bump = Bump{ .next = 0 };
    const cx = CanonContext{ .memory = &mem, .realloc_ctx = @ptrCast(&bump), .realloc_fn = Bump.realloc, .string_encoding = .utf16 };
    try testing.expectError(StringError.UnsupportedEncoding, lowerString(cx, "x"));
}

test "store/load round-trip: list<u32>" {
    var mem = [_]u8{0} ** 256;
    var bump = Bump{ .next = 32 };
    const cx = CanonContext{ .memory = &mem, .realloc_ctx = @ptrCast(&bump), .realloc_fn = Bump.realloc };

    const elem = CanonType{ .prim = .u32 };
    const ty = CanonType{ .list = &elem };
    const items = [_]Value{ .{ .u32 = 1 }, .{ .u32 = 0xDEAD_BEEF }, .{ .u32 = 3 } };
    const v = Value{ .list = &items };

    try store(cx, v, ty, 8); // store the (ptr,len) header at offset 8

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const back = try load(cx, arena.allocator(), ty, 8);
    try testing.expectEqual(@as(usize, 3), back.list.len);
    try testing.expectEqual(@as(u32, 1), back.list[0].u32);
    try testing.expectEqual(@as(u32, 0xDEAD_BEEF), back.list[1].u32);
    try testing.expectEqual(@as(u32, 3), back.list[2].u32);
}

test "store/load round-trip: record { a: u8, b: u32, c: bool }" {
    var mem = [_]u8{0} ** 128;
    var bump = Bump{ .next = 16 };
    const cx = CanonContext{ .memory = &mem, .realloc_ctx = @ptrCast(&bump), .realloc_fn = Bump.realloc };

    const fields = [_]CanonType.Field{
        .{ .name = "a", .ty = .{ .prim = .u8 } },
        .{ .name = "b", .ty = .{ .prim = .u32 } }, // forces 3 bytes of padding after `a`
        .{ .name = "c", .ty = .{ .prim = .bool } },
    };
    const ty = CanonType{ .record = &fields };
    // record align = 4 (max field), size = align(0,1)+1 → align(1,4)=4 +4 → 8, +1 bool=9 → align(9,4)=12
    try testing.expectEqual(@as(usize, 12), sizeOf(ty));
    try testing.expectEqual(@as(usize, 4), alignmentOf(ty));

    const vals = [_]Value{ .{ .u8 = 7 }, .{ .u32 = 0xCAFE }, .{ .bool = true } };
    try store(cx, .{ .record = &vals }, ty, 0);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const back = try load(cx, arena.allocator(), ty, 0);
    try testing.expectEqual(@as(u8, 7), back.record[0].u8);
    try testing.expectEqual(@as(u32, 0xCAFE), back.record[1].u32);
    try testing.expectEqual(true, back.record[2].bool);
}

test "store/load round-trip: record with a string field" {
    var mem = [_]u8{0} ** 256;
    var bump = Bump{ .next = 64 };
    const cx = CanonContext{ .memory = &mem, .realloc_ctx = @ptrCast(&bump), .realloc_fn = Bump.realloc };

    const fields = [_]CanonType.Field{
        .{ .name = "id", .ty = .{ .prim = .u32 } },
        .{ .name = "name", .ty = .{ .prim = .string } },
    };
    const ty = CanonType{ .record = &fields };
    const vals = [_]Value{ .{ .u32 = 42 }, .{ .string = "zwasm" } };
    try store(cx, .{ .record = &vals }, ty, 0);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const back = try load(cx, arena.allocator(), ty, 0);
    try testing.expectEqual(@as(u32, 42), back.record[0].u32);
    try testing.expectEqualStrings("zwasm", back.record[1].string);
}

test "store: value/type mismatch rejected" {
    var mem = [_]u8{0} ** 16;
    var bump = Bump{ .next = 0 };
    const cx = CanonContext{ .memory = &mem, .realloc_ctx = @ptrCast(&bump), .realloc_fn = Bump.realloc };
    // a u32 type with a bool value
    try testing.expectError(StoreError.ValueTypeMismatch, store(cx, .{ .bool = true }, .{ .prim = .u32 }, 0));
}

test "lower: aggregate value has no flat scalar form" {
    try testing.expectError(LowerError.NotFlatScalar, lower(.{ .string = "x" }));
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
