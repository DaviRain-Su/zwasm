# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.M cycle 68 — baked 7 additional multi-memory
  fixtures + fixed `frontendValidate`'s pre-existing data_count
  threading gap (was hardcoded 0, rejecting every memory.init).
  Spec runner shows `[multi-memory] manifests=11 module=18
  return=151 (pass=132 fail=19) trap=24 (pass=24 fail=0)` — major
  jump from cycle 67's manifests=4 return=28 trap=2.
- **D-188 FULLY DISCHARGED** (cycle 61). **D-194 / D-195(c)**
  DISCHARGED earlier. Active debt rows: 16 — all `blocked-by:`;
  zero `now`.

## Active bundle

- None. 10.M continuation runs cycle-by-cycle; each cycle bakes +
  closes any substrate gap surfaced.

## Active task — cycle 69: next autonomous chunk

Cycle 69 candidates (ordered by observable delta):

1. **D-195 sub-gap (b)** — cross-module `(register …)` runner
   registry. With 10.M corpus now driving 19 return fails (most
   trace here), the runner-side registry would close ~10+ fixtures
   across multi-memory + function-references + exception-handling.
   Multi-cycle bundle: baker `register` directive emit + runner
   per-name → Instance map + import-resolution path.
2. **10.M continuation: investigate `data0.{2,4,6}` ParseFailed**
   — wasm-tools itself struggles with these fixtures (truncated
   data sections per upstream wast2json output). Likely upstream
   bake quirk; file as low-priority debt / skip these specific
   sub-fixtures via manifest editing.
3. **10.E EH runtime path** — standalone EH return (try_table.0).
4. **10.M continuation: bake remaining multi-memory fixtures**
   (binary0, exports0, imports0..4, linking0..3, simd_memory*,
   start*, traps*, float_exprs*, float_memory*) — pure infra; may
   surface more substrate gaps.

Cycle 69 picks (1) — highest observable delta. Multi-cycle bundle
starting with baker register emit + runner registry skeleton.

## Larger §10 work (blocked / later)

- **10.M memory64 multi-memory** — autonomous expansion progressing
  well; most remaining corpus gated on D-195(b) cross-module
  register.
- **10.E EH** — validator side spec-correct (cycle 61); runtime EH
  dispatch + cross-module register (D-192) external-gated.
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-68)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[multi-memory       ] return=151(pass=132 fail=19) trap=24(pass=24 fail=0)  <- BIG jump (cycle 68)
[wasm-3.0-assert    ] assert_return pass=500  assert_trap pass=229  assert_invalid pass=118 fail=0
```

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref +
  return_call_ref impl + typed-ref parser (D-195 sub-gap a).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- D-192 / D-195(b) — cross-module `(register …)` runner registry —
  cycle-69 candidate.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0111 (memory64 + multi-memory design).
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-29-gate-tail-vs-exit-code.md` — gate
  verification discipline (exit code primacy).
- ROADMAP §10 row 10.M; `.dev/phase_log/phase10.md`.
