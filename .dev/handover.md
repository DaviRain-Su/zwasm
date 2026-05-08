# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — D-054 + D-055 + 9 other rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: hoist-branch-targets-as-pc, regalloc, coalescer).
5. `.dev/decisions/0031_zir_hoist_pass.md` (D-053 root-cause amend per 8a.6).
6. `.dev/optimisation_log.md` (F/R/O ledger; 8b adoption discipline).

## Current state — Phase 8 / §9.8b / 8b.2 closed (per ADR-0038); **§9.8b / 8b.3 NEXT**

ADR-0038 (`0038_class_aware_alloc_deferral.md`, Status:
Accepted) defers 8b.2-d class-aware allocation to Phase 15
alongside the coalescer detection lift, mirroring ADR-0036's
8b.1 pattern. Justification: liveness type-tagging is the
structural prerequisite for both the allocator's dual-pool
upgrade AND Phase 15's coalescer detection; running it once
in Phase 15 instead of twice (8b.2-d then re-touched in
Phase 15) preserves ABI stability per ADR-0035 + ADR-0036.

8b.2 closes at 8b.2-c (LIFO free-pool refactor at
`c7b0ea5`). 8b.2-d + 8b.2-e dissolve into 8b.2's closure.

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; §9.8a complete
(8a.1-8a.6 [x]); §9.8b / 8b.1 [x] (ADR-0036);
§9.8b / 8b.2 [x] (ADR-0038); **§9.8b / 8b.3 NEXT** — AOT
skeleton (`zwasm compile foo.wasm -o foo.cwasm`).
Phase 8 残 rows = 8b.3 + 8b.4 + 8b.5 + 8b.6.

**Risk**: 8b.4 ≥10% aggregate now concentrates on 8b.3
(AOT cold-start delta) + residual 8a.5 hoist cap-removal
contribution. If 8b.3 underperforms, file ADR-0039 to
amend §9.8b — either re-open class-aware in Phase 8b OR
revise the ≥10% target downward (per ADR-0038
§"Neutral / follow-ups" risk acknowledgement).

## Active task — §9.8b / 8b.3: AOT skeleton **NEXT**

`zwasm compile foo.wasm -o foo.cwasm` produces a loadable
artifact (the generator pipeline; consumer side finalises in
Phase 12). `engine/codegen/aot/` slot already reserved per
ADR-0023; mirror the JIT pipeline's ZIR + regalloc.Allocation
outputs without interpreter coupling. **Bench-delta** measures
cold-start time (.cwasm load) vs JIT first-invocation.

Suggested chunk plan (8b.3):

| #     | Description                                                            | Status   |
|-------|------------------------------------------------------------------------|----------|
| 8b.3-a | Step 0 survey: wasmer AOT path + WasmEdge AOT strategy + v1 AOT attempts (no copy) | **NEXT** |
| 8b.3-b | ADR-0039 design framing — `engine/codegen/aot/` module shape + .cwasm format spec | [ ] |
| 8b.3-c | Implement AOT codegen pipeline (mirror JIT pipeline; emit to .cwasm bytes) | [ ] |
| 8b.3-d | CLI wiring (`zwasm compile`); deserialise + run `.cwasm`; bench-delta cold-start vs JIT | [ ] |
| 8b.3-e | 3-host gate; close 8b.3 [x] with bench-delta in commit body | [ ] |

After 8b.3: 8b.4 (≥10% aggregate; concentrated on 8b.3
contribution per ADR-0038), 8b.5 (Phase 8 boundary audit),
8b.6 (open §9.9).

## Closed §9.8b artefacts (for Phase 15 reference)

- ADR-0035 (post-regalloc slot-aliasing coalescer design)
- ADR-0036 (8b.1 scope downgrade)
- ADR-0037 (regalloc upgrade design + Revision 2 discovery)
- ADR-0038 (class-aware allocation deferral)
- `src/ir/coalesce/pass.zig` (8b.1 scaffolding)
- `src/engine/codegen/shared/regalloc.zig` (8b.2-c LIFO
  free-pool refactor)
- Lessons: `2026-05-09-greedy-local-already-does-reuse.md`

After 8b.2: 8b.3 (AOT skeleton), 8b.4 (≥10% aggregate
exit; absorbs 8b.1 + 8b.2 + 8b.3 contributions), 8b.5
(Phase 8 boundary audit), 8b.6 (open §9.9).

## Coalescer scaffolding (8b.1 [x] artefacts — for Phase 15 reference)

Surface preserved for Phase 15 detection lift:

- `src/ir/coalesce/pass.zig` — pass module + `run` shape +
  `isCoalesceCandidate` (MVP catalogue: `local.tee` /
  `local.get` / `local.set` / `select`) + `deinitArtifacts`.
- `src/ir/zir.zig` — `CoalesceRecord` + `func.coalesced_movs`
  slot.
- `src/engine/codegen/shared/compile.zig` — pipeline
  placement between regalloc and emit.
- `private/notes/p8-8b1-coalescer-survey.md` — Step 0
  survey across cranelift / wasmtime / regalloc2 / wasm3 /
  v1 zwasm (gitignored).
- ADR-0035 (post-regalloc slot-aliasing design) + ADR-0036
  (scope downgrade rationale).

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-054** (`blocked-by: separate investigation`) — OrbStack-
  only; independent of D-053. Likely Rosetta JIT-emulation
  interaction or Linux-x86_64-only path.
- **D-055** (`blocked-by: D-052 + emit_test_*.zig migration`) —
  x86_64 prologue inject deferred (sentinel ARM64-only).
- 9 `blocked-by:` rows — D-007 / D-010 / D-016 / D-018 / D-020
  / D-021 / D-022 / D-026 / D-028 / D-052; barriers all hold.

D-053 closed at `2e0022c` (was promoted to ROADMAP row §9.8a /
8a.5).

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
