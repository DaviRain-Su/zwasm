# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.M-D195b cycle 78 — init-expr `global.get` support
  + data-segment init deferred to after globals. `data0.3` /
  `data0.5` now instantiate cleanly. Spec runner unchanged at
  `[multi-memory] return=407 pass=382 fail=25` (data0.* have no
  assertions; the fix is correctness-only at this granularity).
- **D-188 / D-194 / D-195(c) DISCHARGED** earlier. **D-195(b)
  memory + func + spectest stubs + globals + init-expr global.get
  WIRED** (cycles 71-78). Active debt rows: 17 — all `blocked-by:`;
  zero `now`.

## Active bundle

- None.

## Active task — cycle 79: pivot to 10.E EH runtime path

10.M autonomous portion is now thoroughly complete; further yield
is gated on either (a) upstream-corrupted-fixture re-bake (out-of-
band) or (b) function/global imports for cross-module register-as
forms (low-yield). The next highest-value §10 row is **10.E** —
`[exception-handling] return=34(fail34) trap=2(fail2) exception=4(fail4)`.

Cycle 79 candidates:

1. **10.E EH runtime — try_table.0 instantiate** — currently
   `instantiate FAIL: InstantiateFailed`. Tag section processing
   + throw/catch dispatch wiring. Multi-cycle bundle.
2. **10.E EH runtime — survey existing substrate** — IT-1..IT-6
   landed earlier in this project's history; the validator side
   is spec-correct (cycle 61). Survey what runtime EH path exists
   today + identify the next concrete gap.
3. **Bake more 10.G or function-references fixtures** — both
   gated on external (D-179 wabt / ADR-0123 typed-ref). Defer.

Cycle 79 picks (2) — survey before write. The EH runtime substrate
is multi-cycle-old; understanding the existing state before adding
to it is essential per `textbook_survey.md`.

## Larger §10 work (blocked / later)

- **10.M memory64 multi-memory** — substantially complete (37
  manifests / 619 passing directives + correctness for `data0.3/5`
  init-expr global.get). D-196 tail = upstream-corrupted fixtures
  + named-module register form (low-yield).
- **10.E EH** — validator spec-correct (cycle 61); runtime EH
  dispatch is the next bundle (cycle 79+).
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-78; counts unchanged)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[multi-memory       ] return=407(pass=382 fail=25) trap=238(pass=237 fail=1)
                      invalid=2(pass=2) malformed=2(pass=2) skip=56
[wasm-3.0-assert    ] assert_return pass=750  assert_trap pass=442  assert_invalid pass=120 fail=0
```

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref +
  return_call_ref impl + typed-ref parser (D-195 sub-gap a).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- D-192 — EH cross-module register-as form (specific module-id);
  bundle 10.E runtime path subsumes this.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0114 (EH design).
- ADR-0120 (10.E-payload-prop — Proposed).
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-29-gate-tail-vs-exit-code.md`.
- ROADMAP §10 row 10.E; `.dev/phase_log/phase10.md`.
