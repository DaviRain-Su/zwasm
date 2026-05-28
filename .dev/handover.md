# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.M cycle 73 — baked 15 more multi-memory fixtures
  (float_exprs, float_memory, imports0..4, linking0..3, start0,
  store1, traps0). Spec runner `[multi-memory] manifests=37
  module=69 return=407 (pass=365 fail=42) trap=238 (pass=235
  fail=3) skip=56`. Mac aarch64 test-all + lint green.
- **D-188 FULLY DISCHARGED** (cycle 61). **D-194 / D-195(c)**
  DISCHARGED earlier. **D-195(b) memory-side CLOSED** cycle 72.
  Active debt rows: 16 — all `blocked-by:`; zero `now`.

## Active bundle

- None.

## Active task — cycle 74: next autonomous chunk

Cycle 74 candidates (ordered by observable delta):

1. **D-195(b) extension — cross-module FUNC imports** — ~10
   instantiate-fail fixtures across multi-memory (linking1/2/3,
   imports2/4) + function-references (ref_func.1/3) trace here.
   Smaller bundle than the memory variant (substrate per
   ADR-0066 already there); Linker needs `defineFunc` for
   cross-instance func entries. 1-2 cycles.
2. **10.E EH runtime path** — standalone EH return path
   (try_table.0). Multi-cycle bundle.
3. **`assertion_unlinkable` runner support** — many fixtures use
   this directive (currently skip-impl). Wires the runner to
   actually assert the instantiate-time error class. Lower-yield
   but unblocks several skip-counted directives.
4. **`assert_invalid` text-format runner support** — for fixtures
   with text-mode invalid assertions (skip-impl directive-
   assert_malformed-text). Niche.

Cycle 74 picks (1) — highest observable delta + builds on cycle
72's substrate.

## Larger §10 work (blocked / later)

- **10.M memory64 multi-memory** — substrate cycles 62-68 + corpus
  cycles 65-73 baked 37 manifests / 602 passing directives. Most
  remaining work is D-195(b) FUNC import extension + a few corrupted
  upstream fixtures.
- **10.E EH** — validator side spec-correct (cycle 61); runtime EH
  dispatch + cross-module register (D-192) external-gated.
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-73)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[multi-memory       ] return=407(pass=365 fail=42) trap=238(pass=235 fail=3)  <- +41r +15t (cycle 73)
                      invalid=2(pass=2) malformed=2(pass=2) skip=56
[wasm-3.0-assert    ] assert_return pass=733  assert_trap pass=440  assert_invalid pass=120 fail=0
```

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref +
  return_call_ref impl + typed-ref parser (D-195 sub-gap a).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- D-192 / D-195(b) — memory variant closed; FUNC variant cycle 74.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0111 (memory64 + multi-memory design).
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-29-gate-tail-vs-exit-code.md`.
- ROADMAP §10 row 10.M; `.dev/phase_log/phase10.md`.
