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

## Current state — Phase 9 (SIMD-128) / §9.9/9.4 [x]; **§9.9/9.5 NEXT** (ARM64 NEON emit pt 1)

§9.9/9.4 lands the IR extension:
- `emitPrefixFD` in `src/ir/lower.zig` (mirrors `emitPrefixFC`)
  with MVP catalogue: v128.{const,load*,store,not} + shuffle/
  swizzle + splat (6 shapes) + extract/replace_lane (12 variants)
  + i32x4.add as representative binop.
- `ShapeTag` enum + `Allocation.shape_tags` field +
  `Allocation.shapeTag(vreg)` API in `src/engine/codegen/
  shared/regalloc.zig` per ADR-0041 §"Decision" / 2 + §14
  (single_slot_dual_meaning enforcement). 9.4 MVP returns
  `.scalar` default; 9.5+ ARM64 NEON emit will populate
  `shape_tags` from ZirOp metadata.

13 unit tests cover lower (10: const/load/store/splat shapes/
extract_lane/shuffle/lane bound check/truncated imm/unknown
sub-op) + ShapeTag (3: null default / per-vreg lookup /
out-of-range defensive default).

**§9.9/9.5 NEXT** — ARM64 NEON emit (pt 1): load/store + lane
access + integer arithmetic (i8x16/i16x8/i32x4/i64x2 add/sub/
mul/min/max/avgr). Per ADR-0041 chunk plan: ~900 src + ~250
tests. Wires `Allocation.shape_tags` population from ZirOp
metadata.

## Active task — §9.9/9.5: ARM64 NEON emit (pt 1) **NEXT**

Per ADR-0041 chunk plan + §"Decision" / 2 + 4: ARM64 NEON
load/store + lane access + integer arithmetic. ~900 src +
~250 tests.

Implementation surface:
1. **NEON instruction encoders** in `src/engine/codegen/arm64/
   inst.zig` (or new `inst_neon.zig` if file-size cap pressure
   — current inst.zig at 1463 LOC, soft cap 1000 already
   exceeded). Encoders: `LDR Q<n>` / `STR Q<n>` (memops),
   `MOV V<d>.16B, V<n>.16B` (reg-to-reg), `LDR D<n>` for
   scalar fallback during shape transitions, etc.
2. **Per-op handlers** in `src/engine/codegen/arm64/`: per
   ZirOp (`v128.load`, `v128.store`, `i8x16.splat`, ...).
   Handlers consume the operand stack via the existing pop/
   push helpers, calling NEON encoders.
3. **`Allocation.shape_tags` population** in `regalloc.compute`
   (or a new helper called pre-emit). Walk the ZirInstr stream
   for SIMD ops, mark vregs they touch as `.v128`. ARM64 emit
   queries `alloc.shapeTag(vreg)` to select 16-byte stride.
4. **Spill-frame stride**: the 16-byte stride for v128 vregs
   needs prologue + emit synchronization. Tighter packing
   defers to Phase 15 per ADR-0038; 9.5 MVP just enlarges
   the spill frame conservatively.

Smallest red test: ARM64 emit accepts a ZirInstr stream
containing `i32x4.splat` + `i32x4.add` and produces a
non-empty bytes slice with the expected NEON opcodes
(verifiable via inst.zig encoder unit tests for the same
sequence).

After 9.5: 9.6 ARM64 NEON emit pt 2 (float arith + compare
+ shuffle + conversion) → 9.7/9.8 x86_64 SSE4.1 emit →
9.9 spec test → 9.10 bench → 9.11 audit → 9.12 open §9.10.

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
