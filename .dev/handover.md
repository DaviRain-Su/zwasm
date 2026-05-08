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

## Current state — Phase 8 closed; **Phase 9 (SIMD-128) IN-PROGRESS**, §9.9/9.1 NEXT

Phase 8 boundary closed: §9.8b/8b.5 [x] (lite audit clean
across §A-§G categories; artefact at `private/audit-2026-
05-09.md`) + 8b.6 [x] (Phase Status widget flipped Phase 8
= DONE / Phase 9 = IN-PROGRESS; §9.9 task table expanded
inline with 13 rows from 9.0 → 9.12).

**Phase 9 (SIMD-128)** opens. Goal: `simd.wast` spec test
fail=skip=0 across both backends; SSE4.1 minimum baseline;
SIMD smoke benches against reference runtimes. **🔒 gate**: no.

§9.9/9.0 [x] (this commit). **§9.9/9.1 NEXT** — Step 0
survey for SIMD-128 op catalogue + ARM64 NEON / x86_64
SSE4.1 encoding strategy. Lands `private/notes/p9-9.1-simd-
survey.md`.

## Active task — §9.9/9.1: SIMD-128 Step 0 survey **NEXT**

Per ROADMAP §9.9 task table (just opened), 9.1 dispatches
an Explore subagent surveying the SIMD-128 op catalogue +
encoding strategy across:
- wasmtime/cranelift (ISLE-based SIMD lowering reference)
- wasmer compiler-singlepass (singlepass NEON / SSE4.1)
- zware (Zig idiom for SIMD)
- v1 zwasm (W43 SIMD addr cache + W44 reg class — read,
  never copy per P10)

Survey lands at `private/notes/p9-9.1-simd-survey.md` (200-
400 lines per `textbook_survey.md` Default brief). Headlines:
op grouping (load/store / lane access / arithmetic /
comparison / shuffle / conversion), 1300+ `simd.wast`
assertion catalogue, 3 divergences anchored to P3 + P6 + P7.

After 9.1: 9.2 ADR-NNNN design framing → 9.3 validator
extension → 9.4 IR → 9.5-9.8 emit (ARM64 NEON + x86_64
SSE4.1 split) → 9.9 spec test wire-in → 9.10 bench → 9.11
audit → 9.12 open §9.10 (Wasm 3.0 features).

## Phase 8 close — SHA backfill deferred

Per LOOP.md Phase boundary discipline, §9.8a + §9.8b SHA
backfill is a separate one-commit step. Most §9.8b rows
already carry SHAs in their row text (8b.1/0036, 8b.2/0038,
8b.3-c/b1720a1, 8b.3-d/2460386, 8b.4/this-commit). Bare
[x] rows in §9.8a / §9.8b that need backfill are addressed
in a follow-on `chore(p8): backfill §9.8 SHA pointers`
commit (deferred to next /continue iteration since the
phase-close commit is already substantial).

After 8b.4: 8b.5 (boundary audit_scaffolding) + 8b.6 (open
§9.9 inline + flip Phase Status).

## Closed §9.8b artefacts (for Phase 12 + Phase 15 reference)

- ADRs: 0035 (coalescer design) / 0036 (8b.1 scope down) /
  0037 (regalloc upgrade + Rev 2 discovery) / 0038 (class-
  aware deferral) / 0039 (.cwasm format + Rev 2 numeric
  correction) / 0040 (aggregate target revision)
- Lessons: `2026-05-09-greedy-local-already-does-reuse.md`
- Code: `src/ir/coalesce/pass.zig`, `src/engine/codegen/
  shared/regalloc.zig` LIFO free-pool, `src/engine/codegen/
  aot/{format, serialise, produce}.zig`, `src/cli/compile.zig`
- Surveys (gitignored): `private/notes/p8-8b{1,2,3}-*-
  survey.md`

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
