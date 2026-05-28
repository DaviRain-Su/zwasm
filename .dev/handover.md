# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.M-multi-memory bundle CLOSED (cycle 65). Spec runner
  shows `[multi-memory] manifests=1 module=1 return=2 (pass=2
  fail=0)` — first multi-memory return fixtures green end-to-end on
  the interp path. 4 substrate cycles (62-64) + 1 corpus cycle (65)
  complete the autonomous bundle scope.
- **D-188 FULLY DISCHARGED** (cycle 61). **D-194 / D-195(c)
  DISCHARGED** earlier. Active debt rows: 16 — all `blocked-by:`;
  zero `now`.

## Active bundle

- None — 10.M-multi-memory closed cycle 65. Bundle exit criterion
  met (≥1 multi-memory fixture green on interp).

## Active task — cycle 66: next autonomous chunk

Cycle 66 candidates (ordered by smallest red + best observable
delta):

1. **10.M continuation: memory.size/grow memidx > 0 plumbing** —
   relax `lower.zig::emitMemoryReserved` (currently rejects non-zero
   memidx with `BadBlockType`) + thread memidx into the interp
   memory.size / memory.grow handlers (similar to cycle-64
   load/store). Would unlock more multi-memory fixtures (e.g.,
   `memory_size0.wast`, `memory_grow0.wast`).
2. **10.M continuation: bulk-op memidx > 0** — memory.copy / fill /
   init currently pin to memory 0; spec 3.0 takes per-op
   src_memidx + dst_memidx. Larger scope but same shape as the
   load/store cycle-64 refactor.
3. **10.E EH runtime path** — the cycle-61 validator fix means
   try_table modules now compile spec-correctly; runtime EH
   dispatch (throw/catch unwind via FP-walk) is the remaining
   work. Multi-cycle bundle; gated on cross-module register
   (D-192) for several fixtures but try_table.0 + simpler shapes
   should work standalone.
4. **D-195 sub-gap (b)** — cross-module `(register …)` runner
   registry. Would unblock 2 EH + 1 ref_func instantiate-fail
   modules.

Cycle 66 picks (1) by default — continues the 10.M work that has
freshest substrate context + smallest red (one validator/lower
relax + matching interp handler update).

## Larger §10 work (blocked / later)

- **10.M memory64 multi-memory** — autonomous bundle closed; further
  expansion in cycle 66+ (memory.size/grow then bulk ops).
- **10.E EH** — validator side spec-correct (cycle 61); runtime EH
  dispatch + cross-module register (D-192) external-gated for some
  fixtures; standalone EH return path (cycle 66+ candidate).
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-65)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4)  invalid=18(pass=18 fail=0)
[multi-memory       ] return=2 (pass=2 fail=0)  <- NEW (cycle 65)
[wasm-3.0-assert    ] assert_return pass=370 fail=70  assert_invalid pass=118 fail=0
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

- ADR-0111 (memory64 + multi-memory design) — bundle close anchor.
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- ROADMAP §10 row 10.M; `.dev/phase_log/phase10.md`.
