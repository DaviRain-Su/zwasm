//! Core-binary decode for the COMPONENT validator (rules 11/12 inputs).
//!
//! The closed sub-language here is `Binary.md`'s reused CORE grammar:
//! `core:deftype` (functype / moduletype; GC rec/sub pass through as
//! `.other`), `core:moduledecl`, `core:importdesc`, core valtypes with
//! `(ref N)` heap-type index extraction, and core limits. Only the
//! type-INDEX structure validation needs is modeled.
//!
//! Zone 1 leaf (imports std + leb128 only); `types.zig` re-exports the
//! shapes (file_size_smell P1 split).

const std = @import("std");
const leb128 = @import("../../support/leb128.zig");

pub const Error = error{
    Truncated,
    InvalidDefType,
    InvalidValType,
    InvalidAlias,
    InvalidExternDesc,
    OutOfMemory,
} || leb128.Error;

/// A decoded `core:deftype` (`Binary.md` core type section). Only the
/// type-INDEX structure needed for validation is modeled; GC rec/sub
/// shapes pass through as `.other` (no refs extracted — never a false
/// reject).
pub const CoreDefType = union(enum) {
    /// Type-index refs in a functype's params/results (`(ref N)` heap types).
    func: []const u32,
    module: []const CoreModuleDecl,
    other,
};

/// One `core:moduledecl` — only the module-LOCAL type-space interactions
/// are modeled (imports/exports of `(func (type N))`/tags, nested type
/// defs, outer type aliases); everything else is `.other`.
pub const CoreModuleDecl = union(enum) {
    /// An import/export referencing the module-local type space.
    func_type_ref: u32,
    /// A `core:type` decl — mints a module-local type index.
    type_def: CoreDefType,
    /// `(alias outer ct idx (type))` — ct 0 = the module scope itself,
    /// ct 1 = the enclosing component. Mints a module-local type index.
    outer_type_alias: struct { count: u32, index: u32 },
    other,
};

/// A top-level core-type definition + the core-type space size at its
/// definition point (def-order bounds for its outer refs).
pub const CoreTypeDef = struct {
    def: CoreDefType,
    space_before: u32,
};

// ---- core:type section decode (`Binary.md` core type grammar) ----

/// `core:deftype ::= functype (0x60) | moduletype (0x50 md*) | rec/sub
/// (GC — passed through as .other, body unconsumed)`.
pub fn decodeCoreDefType(a: std.mem.Allocator, body: []const u8, pos: *usize) Error!CoreDefType {
    if (pos.* >= body.len) return Error.Truncated;
    switch (body[pos.*]) {
        0x60 => {
            pos.* += 1;
            var refs: std.ArrayList(u32) = .empty;
            try decodeCoreValTypeVec(a, body, pos, &refs);
            try decodeCoreValTypeVec(a, body, pos, &refs);
            return .{ .func = refs.items };
        },
        0x50 => {
            pos.* += 1;
            const n = try leb128.readUleb128(u32, body, pos);
            var decls: std.ArrayList(CoreModuleDecl) = .empty;
            var i: u32 = 0;
            while (i < n) : (i += 1) {
                try decls.append(a, try decodeCoreModuleDecl(a, body, pos));
            }
            return .{ .module = decls.items };
        },
        // GC rec groups / sub types / struct / array — not modeled yet;
        // leave the body unconsumed (each core-type section holds one
        // deftype, so nothing follows that we would misparse).
        else => return .other,
    }
}

/// `core:moduledecl ::= 0x00 import | 0x01 type | 0x02 alias | 0x03 export`.
fn decodeCoreModuleDecl(a: std.mem.Allocator, body: []const u8, pos: *usize) Error!CoreModuleDecl {
    if (pos.* >= body.len) return Error.Truncated;
    const tag = body[pos.*];
    pos.* += 1;
    switch (tag) {
        0x00 => { // core:import — module name + field name + importdesc
            try skipCoreName(body, pos);
            try skipCoreName(body, pos);
            return decodeCoreImportDesc(body, pos);
        },
        0x01 => return .{ .type_def = try decodeCoreDefType(a, body, pos) },
        0x02 => { // core:alias ::= core:sort (0x01 outer ct idx)
            if (pos.* >= body.len) return Error.Truncated;
            const sort = body[pos.*];
            pos.* += 1;
            if (pos.* >= body.len) return Error.Truncated;
            if (body[pos.*] != 0x01) return Error.InvalidAlias; // only outer in decls
            pos.* += 1;
            const ct = try leb128.readUleb128(u32, body, pos);
            const idx = try leb128.readUleb128(u32, body, pos);
            if (sort == 0x10) return .{ .outer_type_alias = .{ .count = ct, .index = idx } };
            return .other;
        },
        0x03 => { // core:exportdecl ::= name importdesc
            try skipCoreName(body, pos);
            return decodeCoreImportDesc(body, pos);
        },
        else => return Error.InvalidDefType,
    }
}

fn skipCoreName(body: []const u8, pos: *usize) Error!void {
    const n = try leb128.readUleb128(u32, body, pos);
    if (pos.* + n > body.len) return Error.Truncated;
    pos.* += n;
}

/// Core `importdesc`: func/tag carry a module-local TYPE index (modeled);
/// table/memory/global are skipped structurally.
fn decodeCoreImportDesc(body: []const u8, pos: *usize) Error!CoreModuleDecl {
    if (pos.* >= body.len) return Error.Truncated;
    const kind = body[pos.*];
    pos.* += 1;
    switch (kind) {
        0x00 => return .{ .func_type_ref = try leb128.readUleb128(u32, body, pos) },
        0x01 => { // tabletype ::= reftype limits
            try skipCoreValType(body, pos);
            try skipCoreLimits(body, pos);
            return .other;
        },
        0x02 => { // memtype ::= limits
            try skipCoreLimits(body, pos);
            return .other;
        },
        0x03 => { // globaltype ::= valtype mut
            try skipCoreValType(body, pos);
            if (pos.* >= body.len) return Error.Truncated;
            pos.* += 1;
            return .other;
        },
        0x04 => { // tagtype ::= 0x00 typeidx — references the type space too
            if (pos.* >= body.len) return Error.Truncated;
            pos.* += 1;
            return .{ .func_type_ref = try leb128.readUleb128(u32, body, pos) };
        },
        else => return Error.InvalidExternDesc,
    }
}

fn decodeCoreValTypeVec(a: std.mem.Allocator, body: []const u8, pos: *usize, refs: *std.ArrayList(u32)) Error!void {
    const n = try leb128.readUleb128(u32, body, pos);
    var i: u32 = 0;
    while (i < n) : (i += 1) try decodeCoreValType(a, body, pos, refs);
}

/// One core `valtype`; `(ref [null] ht)` heap-type INDICES are collected
/// into `refs` (they index the core-type space).
fn decodeCoreValType(a: std.mem.Allocator, body: []const u8, pos: *usize, refs: *std.ArrayList(u32)) Error!void {
    if (pos.* >= body.len) return Error.Truncated;
    const b = body[pos.*];
    pos.* += 1;
    switch (b) {
        // numtype / vectype / abstract heap-type shorthands.
        0x7F, 0x7E, 0x7D, 0x7C, 0x7B, 0x70, 0x6F, 0x6E, 0x6D, 0x6C, 0x6B, 0x6A, 0x69, 0x68, 0x67, 0x66, 0x65 => {},
        0x63, 0x64 => { // (ref null ht) / (ref ht)
            const ht = try leb128.readSleb128(i64, body, pos);
            if (ht >= 0) try refs.append(a, @intCast(ht));
        },
        else => return Error.InvalidValType,
    }
}

fn skipCoreValType(body: []const u8, pos: *usize) Error!void {
    var sink: std.ArrayList(u32) = .empty;
    var fba_buf: [64]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&fba_buf);
    return decodeCoreValType(fba.allocator(), body, pos, &sink);
}

/// Core `limits` (incl. shared/memory64 flag variants 0x00..0x07).
fn skipCoreLimits(body: []const u8, pos: *usize) Error!void {
    if (pos.* >= body.len) return Error.Truncated;
    const flags = body[pos.*];
    pos.* += 1;
    if (flags > 0x07) return Error.InvalidDefType;
    _ = try leb128.readUleb128(u64, body, pos);
    if (flags & 0x01 != 0) _ = try leb128.readUleb128(u64, body, pos);
}
