# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 104 (`8304714d`) — `ref.as_non_null` / `br_on_non_null`
  stay polymorphic (`.bot`) in unreachable code instead of collapsing
  to concrete funcref (which mismatched downstream `(ref $sig)`).
  function-references ParseFailed **3 → 1**, return pass **7 → 12**,
  trap pass **1 → 4**.
- Prior: cycle 103 typed-ref table/elem decode + bound check
  (`d24ad2da`); 102 ref.func typed `(ref $sig)` + bundle-1 close
  (`7b9218c2`); 101 ref.as_non_null 0xD4 (`c82e8124`); 100 Gate 4
  BadBlockType (`2fa216b9`).
- Mac aarch64 test + lint green (cycle 104). ubuntu x86_64 SSH gate:
  cycle-103 HEAD confirmed green; cycle-104 kick backgrounded —
  Step 0.7 next resume verifies.

## Active bundle

- **Bundle-ID**: 10.R-funcrefs-tail-2 (follow-up; cycles 105+)
- **Cycles-remaining**: ~1
- **Continuity-memo**: cycle 104 cleared 2 of 3 remaining ParseFailed
  (br_on_non_null.0 + ref_as_non_null.0, via unreachable-polymorphism).
  ONE module left: **`ref_is_null.0`**. Cycle-104 probe (code-section
  index + body dump) corrected the earlier "empty func" guess: code#0
  has `bodylen=7 first=0x00` (NOT empty — starts with `unreachable`)
  and fires **BadValType**. So the func is `unreachable; <ops>` where
  some op reads a reftype byte the validator rejects. Candidate (per
  ref_is_null.0's shape): a typed-`select (result (ref null 0))`
  (0x1C typed-select reftype vec), or another reftype-byte op in
  unreachable context. **Step 0 cycle 105**: dump code#0's 7 bytes
  (re-add the body-slice probe) to name the exact op, then fix.
- **Exit-condition**: function-references ParseFailed = 0 (all 15
  modules across the 7 manifests compile) — currently 1. Cycle 105
  closes the bundle when ref_is_null.0 clears.

## Active task — cycle 105: ref_is_null.0 BadValType (last ParseFailed → bundle close)

`ref_is_null.0` code#0 (`bodylen=7 first=0x00`) fails BadValType in an
`unreachable; …` body. **Step 0**: re-add the per-func probe in
`instantiate.zig` printing `code.body` bytes for the failing func, run
`zig build test-spec-wasm-3.0-assert`, read the 7 bytes to identify the
reftype-byte op (likely `0x1C` typed-`select` with a `(ref null 0)`
result, or a typed-ref op the validator's reftype reader rejects).
Smallest red test per the localized op (a `validateFunctionWithMemIdx-
AndTags` body test). On clear: ParseFailed = 0 → **close bundle
10.R-funcrefs-tail-2** (delta-cite return 7→12, ParseFailed 3→0) and
open follow-up for the function-references return pass-rate (12/39 →
the assert_return bodies that parse but mis-execute: call_ref dispatch,
ref.func runtime value).

## Larger §10 work (later bundles)

- **10.E EH spec corpus (Gate 1 / D-192)** — try_table.1.wasm imports
  `test::e0` tag + `test::throw` func from try_table.0.wasm; runner
  registry needs tag + func cross-module binding. Gate 2 (exnref byte
  `0x69` standalone + `ValType.exnref` pub-const) folds in here.
- **10.G WasmGC** — corpus baked (568 directives) but impl=0%; ZIR ops
  + heap impl + subtype lattice. NOTE: `valTypeIsSubtypeFree`'s
  `(ref $concrete) <: func` rule assumes pre-GC (all concrete = func
  type); 10.G must refine once struct/array heads enter module_types.
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-104)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass) exception=4(fail4)
[function-references] return=39(pass=12 fail=21) trap=4(pass=4) invalid=18(pass) ParseFailed=1 (10→7→6→3→1)
[gc                 ] return=407(fail) trap=100(fail) invalid=60(pass=55 fail=5) malformed=1(pass)
[multi-memory       ] return=407(pass=371 fail=36) trap=238(pass=237 fail=1)
```

## Open questions / blockers

- ADR-0120 / ADR-0123: Accepted; impl autonomous. ADR-0123 D4
  (ref.func typed) landed cycle 102.
- D-192: cross-module register substrate. New bundle after
  10.R-funcrefs-tail-2 closes.
- D-186 (return_call_ref): discharge predicate met by ADR-0123 D4 +
  cycle-102 opRefFunc typed push.

## Key refs

- ADR-0120 (Accepted — EH payload), ADR-0123 (Accepted — typed-ref;
  D4 ref.func typed landed cycle 102).
- `.dev/lessons/2026-05-28-funcrefs-tail-error-classes.md` (gate
  inventory + cycle-101/102 re-probe maps).
- ROADMAP §10; `.dev/phase_log/phase10.md`.
