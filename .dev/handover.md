# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.M cycle 66 — memory.size / memory.grow memidx > 0
  plumbing (lower + validator + interp). Baked
  `multi-memory/memory_size0.wast`. Spec runner shows
  `[multi-memory] manifests=2 module=2 return=9 (pass=9 fail=0)`
  (up from return=2 last cycle). Mac aarch64 test-all + lint green
  (verified by exit code).
- **D-188 FULLY DISCHARGED** (cycle 61). **D-194 / D-195(c)**
  DISCHARGED earlier. Active debt rows: 16 — all `blocked-by:`;
  zero `now`.

## Active bundle

- None — 10.M-multi-memory closed cycle 65; cycles 64 / 66 are
  autonomous continuations expanding the same area. Cycle 67+ can
  remain in 10.M scope or pivot.

## Active task — cycle 67: next autonomous chunk

Cycle 67 candidates (ordered by smallest red + observable delta):

1. **10.M continuation: bulk-op memidx > 0** —
   `memory.copy` / `memory.fill` / `memory.init` currently pin
   memory 0; spec 3.0 takes per-op src_memidx + dst_memidx.
   Similar shape to cycle 64-66 (lower + validator + interp
   refactor). Would unlock `data0.wast` / `data1.wast` /
   `memory_copy0.wast` etc. from the upstream multi-memory corpus.
2. **10.M continuation: bake more multi-memory fixtures** —
   `load0`/`memory_size0` proved the substrate; the upstream
   corpus has ~30 fixtures (address0, align0, binary0, data0,
   exports0, float_exprs0/1, float_memory0, imports0..4,
   linking0..3, memory_copy0, memory_init0, memory_grow0,
   memory_size0/1, memory_trap0/1, simd_memory*, start*,
   store*, traps*). Pick the ones that only use already-wired
   ops (load/store/size; not bulk-ops/imports yet). Pure infra
   chunk.
3. **D-195 sub-gap (b)** — cross-module `(register …)` runner
   registry; would unblock 2 EH + 1 ref_func instantiate-fail
   modules.
4. **10.E EH runtime path** — standalone EH return path
   (try_table.0 instantiate fixture). Multi-cycle.

Cycle 67 picks (1) by default — bulk-op refactor mirrors cycle
64-66 pattern, has clearest observable delta (unlocks
data0/memory_copy0 fixtures).

## Larger §10 work (blocked / later)

- **10.M memory64 multi-memory** — autonomous expansion in
  progress (cycles 62-66 done; bulk-ops + corpus expansion ahead).
- **10.E EH** — validator side spec-correct (cycle 61); runtime EH
  dispatch + cross-module register (D-192) external-gated for
  several fixtures.
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-66)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[multi-memory       ] return=9 (pass=9 fail=0)  <- +7 from memory_size0 (cycle 66)
[wasm-3.0-assert    ] assert_return pass=377  assert_invalid pass=118 fail=0
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

- ADR-0111 (memory64 + multi-memory design) — bundle anchor.
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-29-gate-tail-vs-exit-code.md` — gate
  verification discipline (exit code primacy).
- ROADMAP §10 row 10.M; `.dev/phase_log/phase10.md`.
