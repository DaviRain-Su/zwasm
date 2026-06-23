# 0201 — JIT funcref-table grow (dual-view mirror grow-headroom + guest-resolve/host-clear asymmetry)

- **Status**: Accepted (2026-06-23 — autonomous /continue, ADR-0153 rework + ADR-0068 amendment)
- **Date**: 2026-06-23
- **Author**: zwasm v2 maintainer (Phase 17 plateau — D-497 discharge)
- **Tags**: phase-17, jit, abi, table, call-indirect, grow, funcref, 9.12-audit, amends-0068

## Context

`table.grow` on a **funcref** table backed by a JIT instance is rejected on
both paths (D-497):

- **Guest** `table.grow` emits an indirect call through `JitRuntime.table_grow_fn`;
  the only real implementation, `setup.jitTableGrow`, returns `-1` for any table
  carrying a funcptr mirror (`if (@intFromPtr(d.funcptrs) != 0) return -1`).
- **Host** C-API `wasm_table_grow` → `JitInstance.growTable` → the same
  `jitTableGrow`, so it returns `false` for funcref tables (interp reallocs the
  refs slice and supports it).

Masked because `test-spec` runs on interp, so no guest funcref `table.grow` +
`call_indirect`-grown-slot path is exercised on JIT.

Two structural barriers (per ADR-0068's dual-view storage):

1. **No grow headroom in the funcptr/typeidx mirrors.** Per ADR-0068 a funcref
   table has a parallel `funcptrs` (native code entry) + `typeidxs` (sig check)
   view alongside `refs`. Non-funcref `refs` pre-allocate to a capped grow
   capacity (`growCapacity`, 65536) so `jitTableGrow` bumps `.len` without
   realloc; **funcref tables stay at `min`** (the mirrors are slices into the
   shared `funcptrs_buf`/`typeidxs_buf` (table 0) and `extra_*_buf` (tables 1+)
   arenas, which cannot realloc one slice). So a grown funcref slot has nowhere
   to write its funcptr/typeidx.

2. **Guest needs funcptr resolution; host must not dereference the init ref.**
   `call_indirect` on a grown funcref slot reads the funcptr/typeidx mirror, so
   for spec-correct guest growth the new slots must carry the resolved native
   entry. The guest's `init` is always a real funcref (`*FuncEntity`), so
   resolution = read `fe.funcptr` + `fe.typeidx` (the SAME fields JIT
   `emitTableSet` mirrors via `LDR`). The **host** C-API init `*Ref.ref` may be
   forged (the codebase's `tableSetRef` deliberately never dereferences it —
   clears the funcptr to the sentinel, so a later `call_indirect` traps cleanly
   rather than jumping to garbage). Dereferencing a forged ref as `*FuncEntity`
   would SEGV.

## Decision

Implement funcref-table grow on JIT, amending ADR-0068's storage shape:

1. **Grow-headroom for funcref mirrors.** `growCapacity` includes funcref tables
   (cap at `grow_cap`, never below `min`, honour declared `max`). Size
   `funcptrs_buf`/`typeidxs_buf` (table 0) and `extra_funcptrs_buf`/
   `extra_typeidxs_buf` (tables 1+) to per-table grow capacity, and stride the
   per-table offsets (`extra_offs`) by grow capacity, not `min`. `.max` (the
   grow cap-check bound) = the pre-allocated capacity, as for non-funcref.

2. **Two grow entry points** sharing a refs/cap-check core:
   - `jitTableGrowGuest` (installed as `table_grow_fn`) — for a non-null funcref
     `init`, resolve `*FuncEntity` → `fe.funcptr`/`fe.typeidx` and write the
     funcptr/typeidx mirrors via `rt.tables_jit_ci_ptr[tableidx]` (reaches both
     mirrors per table without a `TableSlice` layout change). Null init →
     funcptr `0` + typeidx sentinel `maxInt(u32)` (clean call_indirect trap).
   - `jitTableGrowHost` (called by `growTable`) — fail-safe: fill `refs` only;
     funcptr `0` + typeidx sentinel for every new slot (never dereference a
     possibly-forged host ref, mirroring `tableSetRef`). A host that then wants a
     callable grown funcref slot uses `wasm_table_set` (already mirror-aware).

   The existing `jitTableGrow` becomes the shared non-funcref + refs/cap core.

## Consequences

- Guest `table.grow` funcref + `call_indirect` of a grown slot is spec-correct
  on JIT (arm64 + x86_64). Host C-API funcref grow returns the old size; grown
  slots read back via `wasm_table_get` and are callable after `wasm_table_set`.
- Memory: a growable funcref table pre-allocates its mirrors to the grow cap
  (same policy non-funcref `refs` already pay). Non-growable (`max == min`)
  funcref tables are unchanged.
- ABI-sensitive (`call_indirect` reads the grown mirror) → 3-host gate including
  windowsmini before any `main` merge.
- No `TableSlice` extern layout change (typeidx reached via `tables_jit_ci_ptr`),
  so JIT-emitted call_indirect/table-op offsets are untouched.

## Amends

ADR-0068 (dual-view table storage): the funcptr/typeidx mirrors now carry grow
headroom for funcref tables, and grow has a guest-resolve / host-clear split.
