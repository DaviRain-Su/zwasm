# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `1bf0b798` — feat(p10): try_table per-clause label-type
  validation (10.R cycle 61, D-188 FULLY DISCHARGED). `validateCatchVec`
  now enforces catch / catch_all label-type matching; catch_ref /
  catch_all_ref reject under v2's exnref-less ValType subset (tighten
  to structural matching when exnref lands via D-192). Mac aarch64
  test-all + lint green. **`assert_invalid pass=118 fail=0`** across
  full wasm-3.0-assert corpus.
- **D-188 FULLY DISCHARGED** across 3 cycles: ref.1..5 (initial fix),
  ref_func.4/5 (cycle 60), try_table.8/10 (cycle 61). Bisect retained
  at `accepted_count == 0` as regression marker.
- **D-194 / D-195(c) DISCHARGED** earlier (cycles 58 / 60). Active
  debt rows: 16 — all `blocked-by:` with named barriers; zero `now`
  rows.

## Active bundle

- None — 10.R-function-references closed cycle 59; subsequent cycles
  (60-61) were autonomous-eligible single-cycle chunks (D-195 sub-gap
  c, D-188 EH validator close) outside any bundle. No active multi-
  cycle integration.

## Active task — cycle 62: next autonomous chunk

Cycle 62 candidates (ordered by smallest red + best observable delta):

1. **10.M memory64 multi-memory** — `memories: []MemoryInstance`
   plumbing per ROADMAP §10 row 10.M. Spec single-memory cases all
   pass; multi-memory adds `memidx > 0` reachability. Independent
   of ADR-0120 / 0123 / D-179. Likely the cleanest next bundle.
2. **D-195 sub-gap (b)** — cross-module `(register …)` runner
   registry; sibling to D-192. Would unblock 2 EH + 1 ref_func
   instantiate-fail modules. Spec runner observable: drops
   `instantiate FAIL` count by 3.
3. **10.E EH runtime path** — throw / try_table interp execution
   (return + trap fixtures); currently 34 return + 2 trap + 4
   exception directives all fail at instantiate (D-192 blocker on
   try_table.1) — the validator side is now spec-correct as of
   cycle 61, but the runtime EH dispatch needs wiring.

Cycle 62 picks (1) — multi-memory is non-blocked, well-scoped, and
the spec corpus already has memory64 fixtures to anchor a smallest
red.

## Larger §10 work (blocked / later)

- **10.M memory64** — single-memory spec passes; multi-memory work
  remains (cycle-62 target). clang_wasm64 realworld gated on D-179.
- **10.E EH** — validator side spec-correct as of cycle 61; runtime
  EH dispatch + cross-module register (D-192) remain external-gated.
- **10.G WasmGC op-corpus** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-61)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4)  invalid=18(pass=18 fail=0)
[wasm-3.0-assert    ] assert_invalid pass=118 fail=0  <- D-188 fully closed
```

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref +
  return_call_ref impl + typed-ref parser (D-195 sub-gap a).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- D-192 — EH return/trap fixtures blocked on cross-module register +
  exnref ValType.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0122 (test skip categorization) — D-193 discharge complete.
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- ROADMAP §10 rows 10.M / 10.R / 10.TC / 10.E; `.dev/phase_log/phase10.md`.
