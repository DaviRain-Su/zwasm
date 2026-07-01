# 0131 — GC type-identity table materialised for func-subtyping (not just heap need); concreteReaches authoritative in call_indirect

- **Status**: Accepted (2026-06-02 — autonomous loop; D-232 root-cause fix, verified interp corpus trap 4→0 + Mac test-all green)
- **Date**: 2026-06-02
- **Author**: claude (autonomous loop)
- **Tags**: gc, type-subtyping, call_indirect, call_ref, gc_type_infos, needs_gc_heap, ADR-0115, ADR-0116, ADR-0126, §3.3.5.5, D-232, Phase 10 / 10.G
- **Paired**: D-232 (discharged this commit); amends the materialisation trigger of ADR-0115 D2; applies ADR-0116/0126 subtype machinery.

## Context

The interp's `call_indirect` / `call_ref` accepted a callee iff
`sigEq(callee.sig, expected) or concreteReaches(...)` (mvp.zig). `concreteReaches`
(the §3.3.5.5 subtype check) needs the per-instance `gc_type_infos` table
(supertype chains + canonical ids + finality, ADR-0116/0126). That table was
materialised ONLY when `module.needs_gc_heap` (ADR-0115 D2 — a struct/array/heap-
reftype byte scan). 4 `gc/type-subtyping` interp `assert_trap` tests failed
(D-232): modules declaring `sub`/`sub final` on FUNC types (no struct/array) get
`needs_gc_heap=false` → no `gc_type_infos` → `concreteReaches` blind (returns
false) → the `sigEq` arm short-circuits, and its purely-structural compare
(params/results only) wrongly accepts structurally-equal-but-DISTINCT types
(`$t1=(sub (func))` vs `$t2=(sub final (func))`; or a supertype called as a
subtype). They returned normally where the spec requires an "indirect call" trap.

A probe (since reverted) proved all 23 `sigEq=true, concreteReaches=false` accepts
had `gti=false`, and only 4 were bugs (19 were genuinely non-GC modules where
`sigEq` is correct) — so naively gating `sigEq` off for "GC" would regress 19.

## Decision

1. **Decouple `gc_type_infos` materialisation from `needs_gc_heap`.** Materialise
   the type-identity table when `needs_gc_heap` OR the module uses type
   subtyping (any non-final type OR any with a declared supertype — the
   `usesTypeSubtyping` predicate). A func-subtyping module has no heap objects
   but still needs the table for correct subtype checks. **ADR-0115 zero-overhead
   for non-GC modules is preserved** by a cheap byte pre-filter
   (`mayUseTypeSubtyping`: scan the type section for the `sub` 0x50 / `sub final`
   0x4F forms) that skips the decode entirely when absent; the precise
   `usesTypeSubtyping` (post-decode) then rejects byte false-positives. (Heap slab
   allocation stays gated on `needs_gc_heap` — unchanged.)
2. **`concreteReaches` is AUTHORITATIVE in `call_indirect`/`call_ref` when gti is
   present** (same-module): `accepted = if (gti) concreteReaches else sigEq`. The
   structural `sigEq` is used only for non-subtyping modules and cross-module
   calls (no shared type space). This makes the §3.3.5.5 subtype relation —
   respecting type identity + finality — the decider for subtyping modules.

Result: interp `gc/type-subtyping` `assert_trap` 4→0; interp wasm-3.0 corpus fully
green (assert_return 1233/0, assert_trap 562/0, all categories fail=0); Mac
test-all green (no regression across the broadened instantiate path).

## Consequences

- A bare `(func)` and a `(sub final (func))` with no super are canonically
  structural (≡) → `usesTypeSubtyping` returns false → `sigEq` remains the check
  there (correct: they ARE the same type). The fix only bites when an explicit
  open `sub` or a declared supertype creates a non-structural identity.
- The gti block now decodes the type section for func-subtyping modules too (the
  byte pre-filter bounds this to subtyping modules). Consolidating this decode
  with `instantiateInternal`'s is still a future cycle (pre-existing TODO).
- Same fix applies on the JIT path if/when JIT runs these modules (interp-only
  here; JIT gc/type-subtyping re-check tracked in the bundle).

## Alternatives rejected

- **Extend `needs_gc_heap` byte-scan with 0x50/0x4F** (heap + gti both) — rejected:
  allocates a useless heap for func-subtyping modules AND, combined with decision
  2, a byte false-positive would route a non-GC module's `call_indirect` through
  `concreteReaches` (raw_typeidx-sensitive) → regression risk. The precise
  post-decode predicate avoids this.
- **Gate the `sigEq` arm off for all GC modules** — rejected: 19 of 23 `sigEq`-only
  accepts are legit non-GC; would regress them.
- **Always materialise gti** — rejected: violates ADR-0115 zero-overhead for plain
  MVP modules.
