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

## Current state — Phase 9 (SIMD-128) / §9.9/9.1 [x]; **§9.9/9.2 NEXT** (ADR design framing)

§9.9/9.1 Step 0 survey complete (`private/notes/p9-9.1-simd-
survey.md`, 302 lines, gitignored). Headlines:
- 415 op variants across 59 spec test files; 171 ZirOp pre-
  declared across 8 categories.
- Three divergences anchored to project principles: (a) one
  ZirOp per operation (shape-as-variant); (b) reuse FP-class
  register pool; (c) spec-fidelity float ops (NEON must
  explicitly trap on IEEE-754 specials, not silently saturate).
- SSE4.1 minimum baseline confirmed correct (PMULLD / PINSRB /
  PBLENDVB are SSE4.1-only).
- §9.2-9.10 chunk plan: ~4500 LOC total across both backends.

§9.8 SHA backfill landed at `4af7acd` per LOOP.md phase-
boundary one-commit bookkeeping discipline.

**§9.9/9.2 NEXT** — ADR-NNNN design framing for SIMD-128:
ZirOp catalogue + register-class extension (FP-class pool
reuse) + dispatch-table integration via `feature/simd_128/
register.zig` + spec-fidelity strategy.

## Active task — §9.9/9.2: SIMD-128 ADR design framing **NEXT**

Per the survey + ROADMAP §9.9 row text: ADR-NNNN frames the
design choices. Substantial draft (~10 pages per survey
estimate) covering:

1. **ZirOp catalogue**: shape-as-variant decision (one ZirOp
   per `<shape>.<op>` combination) per P6 + §A12. Confirms
   that the existing 171 ZirOp pre-declarations cover the
   415 spec ops via shape-suffix encoding.
2. **Register-class extension**: v128 vregs reuse the FP-
   class register pool (`max_reg_slots_fp = 13` for ARM64
   V16-V28; XMM0-XMM15 for x86_64). Spill-frame stride
   diverges (8 bytes scalar / 16 bytes v128) — needs shape
   tag to disambiguate. **W54-class regression risk**: per
   `single_slot_dual_meaning.md`, the slot id alone can't
   carry shape semantics; design must surface shape as a
   separate axis (RegClass hint) not packed into slot id.
3. **Feature-register pattern**: SIMD-128 ops register into
   the central dispatch table at startup via `feature/simd_
   128/register.zig` (per ADR-0023 §4.5). Validator + parser
   + interpreter + emit consult the dispatch table only —
   no `if (simd_enabled)` branching in shared code per A12.
4. **Spec-fidelity float strategy**: ARM64 NEON's silently-
   saturating semantics must be overridden to match Wasm's
   IEEE-754 quirks (trap on special values where spec
   demands).
5. **SSE4.1 minimum baseline**: PMULLD + PINSRB/W/D + PBLENDVB
   require SSE4.1; runtime feature detection refuses startup
   on older CPUs. Cite Intel SDM line ranges.

Estimated chunk size: ~250-350 LOC ADR (similar to ADR-0035
+ ADR-0038 shape). After 9.2: 9.3 validator (~150 LOC) →
9.4 IR ZirOp catalogue + lower paths (~450 LOC) → 9.5-9.8
ARM64 + x86_64 emit (~3600 LOC across 4 chunks) → 9.9 spec
test wire-in → 9.10 bench → 9.11 boundary audit → 9.12 open
§9.10 (Wasm 3.0).

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
