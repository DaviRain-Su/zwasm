---
ADR: 0121
Title: Struct / array typedef parse + RTT TypeInfo runtime layout
Status: Proposed
Date: 2026-05-27
Related: ADR-0115 (GC heap), ADR-0116 (GC roots + RTT + i31)
---

## Context

The 10.G-op_gc bundle (cycles 7-12 per
`.dev/phase10_g_op_bundle_plan.md`) wired the no-RTT Wasm 3.0 GC ops
(ref.test / ref.cast / br_on_cast / any↔extern convert / ref.eq /
array.len + i31 trio) — all reachable through validator + lower +
interp without any struct- or array-shape decoding. The next 6+
cycles target the heap-allocating ops (struct.new / struct.get /
struct.set + array.new family) which need:

1. Type-section parser support for `0x5F` (struct-type) + `0x5E`
   (array-type) prefixes (currently `decodeTypes` rejects with
   `Error.InvalidFunctype` on the first non-`0x60` byte).
2. A runtime layout for `StructInfo` / `ArrayInfo` carrying field
   counts + field valtypes + (eventually) an RTT-display chain per
   ADR-0116 §"Internal hierarchy" 8-deep display.
3. A discipline for how `module_types[idx]` resolves — today it's
   `[]FuncType`; the spec puts func/struct/array in the same index
   space.

Three call-site survey paths show ~205 references to
`Types` / `module_types` / `types.items` across `src/` + `test/`,
so a naive `union(enum)` replacement is invasive.

## Decision

### D1 — `Types` keeps `items: []FuncType` (no breaking refactor)

Existing callers reading `items[idx]` continue to read `FuncType`.
Non-func entries land as zero-initialised `FuncType{}` (empty
params + results) in this slot — never consulted by validators
because the kind is checked first.

### D2 — Parallel `kinds: []TypeKind` + sparse side tables

```zig
pub const TypeKind = enum(u8) { func, structdef, arraydef };

pub const StructFieldType = struct {
    valtype: ValType,
    mutable: bool,
};

pub const StructDef = struct {
    fields: []const StructFieldType,
};

pub const ArrayDef = struct {
    element: StructFieldType, // arrays share field-type encoding
};

pub const Types = struct {
    arena: ArenaAllocator,
    items: []FuncType,         // existing, slot=FuncType{} for non-func
    kinds: []TypeKind,         // NEW — parallel to items
    struct_defs: []?StructDef, // NEW — sparse; non-null iff kinds[i]==.structdef
    array_defs: []?ArrayDef,   // NEW — sparse; non-null iff kinds[i]==.arraydef
    pub fn deinit(self: *Types) void { self.arena.deinit(); }
};
```

`struct_defs` and `array_defs` are typeidx-indexed (same length
as `items`) with `?T` slots so the typeidx → typedef lookup stays
O(1) without a hashmap.

### D3 — `StructFieldType` is the shared "field type" carrier

Wasm 3.0 GC §"Storage and field types" defines a field as `(valtype |
packed_type, mut)`. We collapse `packed_type` (i8 / i16) onto
`ValType` extensions in a follow-up cycle (D-NNN to be filed when
sub-chunk 5 lands). For ADR-0121 first cut, fields are restricted to
the existing `ValType` set; packed-type encoding rejected with
`Error.NotImplemented`.

### D4 — `decodeTypes` decoder dispatch

```zig
switch (body[pos]) {
    0x60 => /* existing functype path */,
    0x5F => /* new structtype path; field-count uleb32 + per-field {valtype, mut byte} */,
    0x5E => /* new arraytype path; one field-type triple */,
    else => return Error.InvalidFunctype,
}
```

The error name `InvalidFunctype` reads inaccurately once 0x5F /
0x5E are valid. Rename → `InvalidTypeDef` deferred to a small
follow-up commit (the rename touches ~6 sites; not gated by this
ADR).

### D5 — Validator integration deferred to ADR-0121 follow-ups

This ADR lands the parse path + side-table substrate. Validator
integration (struct.new's per-field pop, array.new's len/init pop,
struct.get / struct.set field-type lookup) lands per sub-chunk 5 /
6 of the bundle plan, each citing this ADR.

### D6 — RTT layout defers to ADR-0116 amendment

ADR-0116 specifies the 8-deep RTT display. The runtime materialisation
(`*const StructInfo` / `*const ArrayInfo` in the GC heap header per
ADR-0115 §"Object header") is the subject of a future ADR-0116
amendment, not ADR-0121. ADR-0121 ends at the parse + side-table
boundary.

## Alternatives

(A) **Replace `items: []FuncType` with `[]TypeDef` union** — natural
shape but cascades through ~205 call sites + every `FuncType`-typed
local variable. Rejected: too invasive for one cycle; the parallel
side-table preserves backward-compat AND localises the
TypeKind discipline.

(B) **HashMap-backed `typeidx → StructDef`** — saves a per-typeidx
slot but adds runtime hash cost on every validator field-pop.
Rejected: indices are small (typically < 100), dense arrays win.

(C) **Defer the parse extension; reject 0x5F at parse time and bring
the gc spec corpus online via D-179 wabt baking** — kicks the can
to an external blocker. Rejected: parse-side substrate is
autonomous-eligible work that unblocks the validator integration
cycles even before D-179 dissolves.

## Consequences

+ Parse-side substrate lands in a single cycle (~50 LOC + 2-3 tests).
+ Existing FuncType-only validation paths stay untouched.
+ Future struct.new / array.new vertical slices have a typed
  fields[] / element to consume instead of synthesising metadata.
- Sparse `?StructDef[]` / `?ArrayDef[]` storage costs `sizeof(?T)`
  per typeidx (~24 bytes/slot) even when no struct/array types
  are declared. Acceptable; module type sections are small.
- D5 means struct.new validator can't ship until ADR-0121 sub-cycle
  lands; current 10.G-op_gc bundle is at the natural pivot point.

## References

- `.dev/phase10_g_op_bundle_plan.md` sub-chunks 5 + 6
- ADR-0115 §"Object header" (where StructInfo/ArrayInfo eventually lives)
- ADR-0116 §"Internal hierarchy" (RTT 8-deep display)
- Wasm 3.0 GC binary encoding §5 — struct-type (0x5F) + array-type (0x5E)

## Revision history

- 2026-05-27 — Initial draft (10.G op_gc cycle 13 architectural prep).
