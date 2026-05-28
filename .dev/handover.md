# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 102 (`7b9218c2`) — `ref.func` yields the typed
  non-null `(ref $sig)` (ADR-0123 D4) + `(ref $sig) <: func` subtype
  in `valTypeIsSubtypeFree`. **Bundle 10.R-funcrefs-tail CLOSED**:
  exit-condition met (function-references return pass **0 → 7/39**,
  ParseFailed **6 → 3**; delta landed `7b9218c2`).
- Cycle 100 = Gate 4 BadBlockType (`2fa216b9`); cycle 101 =
  ref.as_non_null 0xD4 opcode fix (`c82e8124`).
- Mac aarch64 test + lint green (cycle 102). ubuntu x86_64 SSH gate:
  cycle-101 HEAD confirmed green; cycle-102 kick backgrounded —
  Step 0.7 next resume verifies.

## Active bundle

- **Bundle-ID**: 10.R-funcrefs-tail-2 (follow-up; cycles 103+)
- **Cycles-remaining**: ~3
- **Continuity-memo**: 3 function-references modules still ParseFailed
  after the typed-ref work — `ref_is_null.0`, `br_on_non_null.0`,
  `ref_as_non_null.0`. Two (`ref_is_null.0`, `ref_as_non_null.0`) fail
  **before** the per-function validate loop (section decode / preDecode
  stage) — they use typed-ref tables `(table (ref null 0))` + typed
  elem segments `(elem (table) (ref 0) (ref.func 0))` + declarative
  `(elem func N)`. `br_on_non_null.0` fails IN a func body (its sibling
  `.2` cleared cycle 102, so the gap is specific to `.0`'s shape:
  `block (result (ref 0))` + `br_on_non_null` + `call_ref`).
  **Step 0 each cycle**: re-probe (temp `frontendValidate` per-func
  error print, OR section-decode probe for the pre-loop failures) to
  localize before fixing.
- **Exit-condition**: function-references ParseFailed = 0 (all 15
  modules across the 7 manifests compile) — currently 3.

## Active task — cycle 103: diagnose + fix the highest-yield of the 3 remaining ParseFailed

**Step 0 (re-probe)**: the 2 pre-loop failures need a section-decode
probe (where does `frontendValidate` return false before the per-func
loop?) — likely `sections.decodeTables` rejecting `(ref null 0)`
elem_type, or `sections.decodeElement` rejecting typed elem exprs.
`br_on_non_null.0` needs the per-func error class (temp probe at
instantiate.zig ~line 322). Then fix the highest-yield gate. Smallest
red test per the localized gap (table/elem decode unit test, or a
`validateFunctionWithMemIdxAndTags` body test).

After ParseFailed = 0: raise the function-references return pass-rate
(currently 7/39) — the assert_return bodies that parse but mis-execute
(call_ref dispatch, ref.func runtime value) are the next surface.

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

## Spec runner observable (post-cycle-102)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass) exception=4(fail4)
[function-references] return=39(pass=7 fail=26) trap=4(pass=1 fail=3) invalid=18(pass) ParseFailed=3 (10→7→6→3)
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
