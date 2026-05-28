# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.TC cycle 80 — baked `return_call_indirect.wast`.
  `[tail-call] manifests=2 module=6 return=71 (pass=71) trap=7
  (pass=7) invalid=24 (pass=23 fail=1)` — +40r +7t +13i vs cycle
  79. One new invalid-accepted (return_call_indirect.27;
  elem-only no-code-section gap). Mac aarch64 test-all + lint
  green.
- **D-188 / D-194 / D-195(c) DISCHARGED** earlier. **D-195(b)
  memory + func + spectest + globals + init-expr global.get
  WIRED** (cycles 71-78). Active debt rows: 17 — all
  `blocked-by:`; zero `now`.

## Active bundle

- None.

## Active task — cycle 81: next autonomous chunk

Cycle 81 candidates:

1. **Wasm 1.0/2.0 corpus expansion** — both have many fixtures
   that we haven't all baked. Could add coverage to existing
   wasm-1.0-assert / wasm-2.0-assert runners. 1-2 cycles per
   batch.
2. **elem-only no-code-section ref.func range check** — closes
   the new return_call_indirect.27 invalid-accepted noise. Small
   validator fix in `instantiate.zig::preDecodeSectionBodies` or
   element-section pre-decode. 1 cycle.
3. **10.G WasmGC** — D-179-blocked.
4. **Bench refresh / docs / audit_scaffolding** — phase boundary
   anticipation prep.

Cycle 81 picks (2) — closes the new invalid-accepted gap surfaced
by cycle 80. Quick win, brings tail-call corpus to fully green.

## Larger §10 work (blocked / later)

- **10.E EH runtime** — gated on ADR-0120 Accept (exnref ValType
  user-flip).
- **10.M memory64 multi-memory** — autonomous substantially done.
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-80)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  (pass=71) trap=7 (pass=7) invalid=24 (pass=23 fail=1)  <- +40r +7t +13i (cycle 80)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[multi-memory       ] return=407(pass=382 fail=25) trap=238(pass=237 fail=1)
                      invalid=2(pass=2) malformed=2(pass=2) skip=56
[wasm-3.0-assert    ] assert_return pass=790  assert_trap pass=449  assert_invalid pass=133 fail=1
```

## Open questions / blockers

- ADR-0120 — Status: Proposed; user Accept flip unblocks
  ~30 EH spec directives.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref +
  return_call_ref impl + typed-ref parser (D-195 sub-gap a).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0112 (Tail Call design — 10.TC).
- ADR-0114 (EH design — 10.E).
- ADR-0120 (10.E-payload-prop — Proposed).
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-29-gate-tail-vs-exit-code.md`.
- ROADMAP §10 rows 10.TC / 10.E; `.dev/phase_log/phase10.md`.
