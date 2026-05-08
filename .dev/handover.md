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

## Current state — Phase 8 / §9.8b / 8b.3 [x] + ADR-0040 landed; 8b.4 **NEXT** (substrate audit)

§9.8b / 8b.3 closed (per ADR-0039); 8b.3-c at `b1720a1`
(format + serialise) + 8b.3-d at `2460386` (CLI +
producer). ADR-0040 (`99fcceb1`) revises §9.8b's
aggregate target — substrate work + measurement migrates
to Phase 12 + Phase 15. ROADMAP §9.8b row 8b.4 reframed
from "Bench delta ≥10%" to "Substrate-coherence audit"
per ADR-0040.

**Phase 8 status**: §9.8/8.0-8.4 [x]; §9.8a complete;
§9.8b/8b.1 [x] (ADR-0036), 8b.2 [x] (ADR-0038), 8b.3 [x]
(ADR-0039); **§9.8b/8b.4 NEXT** — substrate-coherence
audit per ADR-0040. After 8b.4: 8b.5 (boundary
`audit_scaffolding`) + 8b.6 (open §9.9 inline).

3-host gates dispatched at `2460386` (running); ADR-0040
+ ROADMAP edits land in subsequent commit on top.

## Active task — §9.8b / 8b.4: Substrate-coherence audit **NEXT**

Per ADR-0040 (Status: Accepted, `99fcceb1`), 8b.4 is now
a **substrate-coherence audit** verifying:

1. `src/ir/coalesce/pass.zig` + `func.coalesced_movs` slot
   are referenced by the Phase 15 coalescer plan.
2. `src/engine/codegen/shared/regalloc.zig` LIFO free-pool
   is the substrate Phase 15's class-aware allocator
   extends.
3. `src/engine/codegen/aot/{format, serialise, produce}.zig`
   + `src/cli/compile.zig` are referenced by the Phase 12
   loader plan.
4. ADR-0036 + ADR-0037 + ADR-0038 + ADR-0039 each cite the
   Phase 15 / Phase 12 lift point in their `Consequences` §
   (verify; amend Revision rows if missing).

Suggested chunk plan (8b.4):

| #     | Description                                                                                  | Status   |
|-------|----------------------------------------------------------------------------------------------|----------|
| 8b.4-a | Audit ADR-0036/0037/0038/0039 Consequences §§ for Phase 12/15 lift-point citations; amend Revisions if absent | **NEXT** |
| 8b.4-b | Phase 12 + Phase 15 ROADMAP row prep: stub task tables noting the inherited bench-delta obligations (per ADR-0040 §"Neutral / follow-ups") | [ ] |
| 8b.4-c | Close 8b.4 [x]; 3-host gate is doc-only so foreground sufficient | [ ] |

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
