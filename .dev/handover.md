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

## Current state — Phase 9 / §9.9/9.5-c-v [x] (i16x8/i32x4 mul); **§9.9/9.5-c-vi NEXT**

§9.9/9.5-c-v adds NEON MUL encoders (encMul16B / encMul8H /
encMul4S; same shape as ADD with bits[15:11] = 10011 vs ADD's
10000) + emitI16x8Mul / emitI32x4Mul handlers + 2 dispatch
arms. Wasm SIMD has no i8x16.mul (encMul16B preserved for
completeness). i64x2.mul defers to 9.5-c-vi since A64 NEON
has no `MUL Vd.2D` instruction — needs multi-instr synthesis.

Per LOOP.md chunk granularity, 9.5 row split:
- 9.5-a/b/c-i…c-v [x]: encoder foundation + shape-tag
  pipeline + Q-form spill + op_simd refactor + lane access +
  ADD/SUB + MUL (16B/8H/4S).
- 9.5-c-vi NEXT: i64x2.mul synthesis (extract/scalar-mul/
  insert sequence) + remaining lane-access shapes (i8x16/
  i16x8/i64x2/f32x4/f64x2 extract/replace_lane).

Mac gates: zone ✓, file_size ✓, spill ✓, lint ✓, test
1224/0/12 (was 1220; +4 MUL encoder tests).

**§9.9/9.5-c-vi NEXT** — i64x2.mul multi-instr synthesis +
extract/replace_lane for i8x16 / i16x8 / i64x2 / f32x4 /
f64x2. The synthesis sequence for i64x2.mul: extract each
i64 lane via UMOV X<rd>, V<rn>.D[i]; scalar MUL via
inst.encMulRR; insert via INS V<rd>.D[i], X<rn>. ~120 src +
~60 tests (estimate; chunk granularity may further split if
the lane-access shape variants exceed thresholds).

## Active task — §9.9/9.5-c-vi: i64x2.mul synthesis + lane access shapes **NEXT**

Per ADR-0041 + 9.5-a's encoder foundation. Wires the NEON
encoders into the ZirOp dispatch path in
`src/engine/codegen/arm64/emit.zig` (or a new
`op_simd.zig` sibling if soft-cap pressure on emit.zig).

MVP handlers (matching 9.4 lower's MVP catalogue):
- `v128.load` (offset payload from emitMemarg) → encLdrQImm
- `v128.store` → encStrQImm
- `i32x4.splat` → encDup4S (reads i32 vreg, emits to v128 vreg)
- `i32x4.add` → encAdd4S (pop 2 v128, push v128)

Cross-cutting concerns:
- **`Allocation.shape_tags` population**: `regalloc.compute()`
  (or a wrapper pre-emit) walks `func.instrs` checking each
  op's ZirOp for v128 shape (any `v128.*`, `i*x*.*`, `f*x*.*`
  prefix) and marks the popped/pushed vregs accordingly.
- **Spill-frame stride**: v128 vregs spill at 16-byte stride
  (NEON `LDR Q` / `STR Q` alignment). Tighter per-shape
  packing defers to Phase 15 per ADR-0038; 9.5 MVP enlarges
  the conservative spill frame.

Smallest red test: arm64/emit.zig accepts a ZirInstr stream
containing `(i32.const 7) + i32x4.splat` and produces a
non-empty bytes slice whose disassembly matches `MOVZ W?, #7;
DUP V?.4S, W?` (bit-pattern verification via inst_neon
encoder tests for the expected DUP word).

After 9.5-b: 9.5-c (extract/replace_lane + remaining int
arith shapes) → 9.6 ARM64 NEON emit pt 2 (float + compare +
shuffle + conversion) → 9.7/9.8 x86_64 SSE4.1 emit → 9.9
spec test → 9.10 bench → 9.11 audit → 9.12 open §9.10.

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
