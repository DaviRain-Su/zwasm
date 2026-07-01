//! Pure file-scope validation helpers extracted from `validator.zig` to keep
//! that file under its size cap (the marker's planned extraction; D-475 table64
//! threading was the cap pressure). These take `zir.*` / `sections.*` / `ValType`
//! and touch NO Validator instance state — a separable sub-language of
//! const-expr typing (§3.4.3), global-init / func-import subtyping (§4.5.10),
//! and type-section subtype validation (ADR-0124). `validator.zig` calls them
//! via `helpers.<fn>` and re-exports each so external callers keep using
//! `validator.<fn>` unchanged.
//!
//! SIBLING-PUB: the `pub` symbols here are consumed only by the sibling
//! `validator.zig` (which re-exports them) + its callers; the pub-ness is an
//! extraction artifact, not a wide public API surface.
const leb128 = @import("../support/leb128.zig");
const zir = @import("../ir/zir.zig");
const sections = @import("../parse/sections.zig");
const gc_subtype = @import("gc_subtype.zig");
const init_expr = @import("../parse/init_expr.zig");
const ValType = zir.ValType;

pub const GlobalEntry = struct {
    valtype: ValType,
    mutable: bool,
};

/// ADR-0124 — does typedef `sub` structurally conform to its declared
/// supertype `sup`? (Same comptype kind; struct width+depth, array
/// element, func param-contravariant/result-covariant.) Used at
/// type-section validation to reject non-conformant `sub`/`sub final`
/// declarations.
pub fn typeDefIsSubtype(sub: u32, sup: u32, types: *const sections.Types) bool {
    if (sub == sup) return true;
    if (sub >= types.kinds.len or sup >= types.kinds.len) return false;
    if (types.kinds[sub] != types.kinds[sup]) return false;
    return switch (types.kinds[sub]) {
        .func => blk: {
            const a = types.items[sub];
            const b = types.items[sup];
            if (a.params.len != b.params.len or a.results.len != b.results.len) break :blk false;
            // params contravariant, results covariant.
            for (a.params, b.params) |ap, bp| if (!gc_subtype.gcValTypeSubtype(bp, ap, types)) break :blk false;
            for (a.results, b.results) |ar, br| if (!gc_subtype.gcValTypeSubtype(ar, br, types)) break :blk false;
            break :blk true;
        },
        .structdef => blk: {
            const a = (types.struct_defs[sub] orelse break :blk false).fields;
            const b = (types.struct_defs[sup] orelse break :blk false).fields;
            if (a.len < b.len) break :blk false; // width
            for (b, 0..) |bf, i| if (!gc_subtype.gcFieldSubtype(a[i], bf, types)) break :blk false; // depth
            break :blk true;
        },
        .arraydef => blk: {
            const a = (types.array_defs[sub] orelse break :blk false).element;
            const b = (types.array_defs[sup] orelse break :blk false).element;
            break :blk gc_subtype.gcFieldSubtype(a, b, types);
        },
    };
}

/// Wasm spec §3.4.3 — infer the result valtype of a *single-instruction*
/// const-expr (global init / offset). Returns null for multi-instruction or
/// unrecognized shapes → caller treats "undeterminable" as "don't reject"
/// (conservative). `ref.func i` → concrete `(ref func_type_indices[i])`
/// (GC-aware); `global.get j` → referenced global's type.
pub fn constExprResultType(
    expr: []const u8,
    global_entries: []const GlobalEntry,
    func_type_indices: []const u32,
) ?ValType {
    if (expr.len < 2) return null;
    var pos: usize = 1;
    const produced: ValType = switch (expr[0]) {
        0x41 => blk: { // i32.const
            _ = leb128.readSleb128(i32, expr, &pos) catch return null;
            break :blk .i32;
        },
        0x42 => blk: { // i64.const
            _ = leb128.readSleb128(i64, expr, &pos) catch return null;
            break :blk .i64;
        },
        0x43 => blk: { // f32.const
            if (pos + 4 > expr.len) return null;
            pos += 4;
            break :blk .f32;
        },
        0x44 => blk: { // f64.const
            if (pos + 8 > expr.len) return null;
            pos += 8;
            break :blk .f64;
        },
        0xD0 => init_expr.readTypedRef(expr, &pos, true) catch return null, // ref.null ht → (ref null ht)
        0xD2 => blk: { // ref.func i → (ref <concrete typeof i>) non-null
            const idx = leb128.readUleb128(u32, expr, &pos) catch return null;
            if (idx >= func_type_indices.len) return null;
            break :blk .{ .ref = .{ .nullable = false, .heap_type = .{ .concrete = func_type_indices[idx] } } };
        },
        0xFD => blk: { // v128.const (only constant SIMD op)
            const sub = leb128.readUleb128(u32, expr, &pos) catch return null;
            if (sub != 0x0C) return null;
            if (pos + 16 > expr.len) return null;
            pos += 16;
            break :blk .v128;
        },
        0x23 => blk: { // global.get j → referenced global's declared type
            const idx = leb128.readUleb128(u32, expr, &pos) catch return null;
            if (idx >= global_entries.len) return null;
            break :blk global_entries[idx].valtype;
        },
        // 0xFB GC ops (struct.new / array.new* / ref.i31 / converts) and any
        // multi-instruction extended-const form: conservative skip.
        else => return null,
    };
    // Require the single producing instruction to be immediately followed
    // by `end` — otherwise it is a multi-instruction expr we don't type.
    if (pos >= expr.len or expr[pos] != 0x0B) return null;
    return produced;
}

/// Wasm spec §3.4.3 — every defined global's init-expr result type must be a
/// subtype of the declared global type (iso-recursive, ADR-0126). Conservative
/// per `constExprResultType`. Closes the `frontendValidate` global-init gap.
pub fn validateGlobalInits(
    defined_globals: []const sections.GlobalDef,
    global_entries: []const GlobalEntry,
    func_type_indices: []const u32,
    types: *const sections.Types,
) bool {
    for (defined_globals) |gd| {
        const produced = constExprResultType(gd.init_expr, global_entries, func_type_indices) orelse continue;
        if (!gc_subtype.gcValTypeSubtype(produced, gd.valtype, types)) return false;
    }
    return true;
}

/// Wasm 3.0 §4.5.10 + §3.3.5.1 — function import-matching: the provided func
/// type must be a SUBTYPE of the declared import type (contravariant params /
/// covariant results), not exact-equal. Same-typespace simplification → D-202.
pub fn funcTypeImportCompatible(
    want: zir.FuncType,
    src: zir.FuncType,
    types: *const sections.Types,
) bool {
    if (want.params.len != src.params.len) return false;
    if (want.results.len != src.results.len) return false;
    // Params contravariant: declared (want) <: provided (src).
    for (want.params, src.params) |wp, sp| {
        if (!gc_subtype.gcValTypeSubtype(wp, sp, types)) return false;
    }
    // Results covariant: provided (src) <: declared (want).
    for (src.results, want.results) |sr, wr| {
        if (!gc_subtype.gcValTypeSubtype(sr, wr, types)) return false;
    }
    return true;
}

/// ADR-0124 — validate every declared subtype relationship in a type
/// section. For each typedef carrying declared supertype(s) (`sub` /
/// `sub final`): at most one supertype (Wasm 3.0 GC MVP), the supertype
/// index defined earlier (no `rec` forward refs in the flattened form),
/// the supertype not final (`sub final` / bare comptype can't be
/// extended), and the subtype structurally conforms. Returns false on
/// any violation. Empty supertypes (bare comptype) are always OK.
pub fn validateTypeSection(types: *const sections.Types) bool {
    for (types.supertypes, 0..) |supers, i| {
        if (supers.len == 0) continue;
        if (supers.len > 1) return false; // GC MVP allows ≤1 supertype
        const s = supers[0];
        if (s >= types.kinds.len) return false; // supertype index out of bounds
        if (s >= i) return false; // supertype must be declared earlier
        if (s < types.finals.len and types.finals[s]) return false; // extending a final type
        if (!typeDefIsSubtype(@intCast(i), s, types)) return false; // structural conformance
    }
    return true;
}
