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

## Current state — Phase 9 (SIMD-128) / §9.9/9.3 [x]; **§9.9/9.4 NEXT**

§9.9/9.3 lands the validator's prefix-`0xFD` dispatch.
Discovery during implementation: the validator uses inline
static dispatch (not the central DispatchTable), so the SIMD
extension mirrors the existing `dispatchPrefixFC` shape inline
in `src/validate/validator.zig`. ADR-0041 amended with
Revision 2 capturing the discovery + adjusted approach
(full dispatch-table-driven validator = Phase 14+ refactor).

MVP catalogue covers v128.const, v128.load/store, splat
(per shape), extract/replace_lane (per shape), binop/unop/
relop ranges, any_true. 10 unit tests cover happy-path +
type-mismatch + truncated-immediate + unknown-sub-opcode.

**§9.9/9.4 NEXT** — IR extension: ZirOp activation (171
already pre-declared in `src/ir/zir.zig`) + lower paths from
prefix-0xFD opcodes to ZirOps + `Allocation.shapeTag()` API
introduction. Estimated ~450 src + ~120 tests per ADR-0041
chunk plan.

## Active task — §9.9/9.4: SIMD-128 IR extension **NEXT**

Per ADR-0041 §"Decision" / 1 + chunk plan: activate the 171
pre-declared SIMD ZirOps (`src/ir/zir.zig`) + lower paths
from validator-accepted prefix-0xFD ops to ZirOps + introduce
`Allocation.shapeTag()` API for per-vreg shape disambiguation
(per ADR-0041 §"Decision" / 2 — `single_slot_dual_meaning.md`
enforcement). The shape-as-variant catalogue means each
prefix-0xFD sub-opcode maps to a single ZirOp via a
straightforward lookup table.

Smallest red test: lower a wasm body with `i32x4.splat
(i32.const 7)` to a ZirInstr stream containing
`@"i32.const"` + `@"i32x4.splat"` ZirOps, and verify
`func.liveness.ranges[v128_vreg].shape == .v128`.

Estimated diff: ~450 src + ~120 tests. After 9.4: 9.5/9.6
ARM64 NEON emit → 9.7/9.8 x86_64 SSE4.1 emit → 9.9 spec
test → 9.10 bench → 9.11 audit → 9.12 open §9.10.

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
