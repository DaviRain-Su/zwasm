# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.7 row — Phase 9 active.
3. `.dev/debt.md` — D-055 / D-057 + 10 `blocked-by:` rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: simd ops, x86_64 SSE/SSE4.1/SSE4.2, ADR-0041 §5).
5. `.dev/decisions/0041_simd_128_design.md` (SSE4.2 baseline post-9.7-m
   amendment).

## Current state — Phase 9 / §9.9 in-flight; **9.9-d-6 NEXT — populateShapeTags vreg-numbering gap (D-061) so v128 select / lane mem dispatch reaches new emit handlers from any function shape**

9.9-d-5 (`618f621d`): ARM64 v128 select + 8 lane mem handlers
(`v128.{load,store}{8,16,32,64}_lane`) added. New encoders
`encCsetmX` (X-form CSETM) + `encDupGen2D` (DUP V.2D from X)
verified against clang-as. The 8 INS/UMOV/scalar load-store
encoders for lane mem already existed. Per-arch divergence
(ARM64 prologue → UMOV → STR vs x86_64 PEXTR-before-prologue)
documented in handler comments.

**Mac aarch64 simd_assert_runner totals after 9.9-d-5**:
226 PASS / 36 FAIL / 296 SKIP — **unchanged vs 9.9-d-4**. The
new emit handlers are wired but unreachable for the
`simd_select.0` fixture today because `populateShapeTags`
returns null when no SIMD ops appear in the function body —
bare `local.get v128 / select` therefore routes through the
.scalar branch. Filed as **D-061**.

Residual 36 fails (same as 9.9-d-4):
- 3 compile UnsupportedOp — `simd_select.0` (D-061), `simd_const.387`
  (local.tee with v128 type — separate emit gap), `simd_align.90`.
- 21 value-mismatch (`got v128`) — defer to 9.9-d-7.
- 3 small validator surfaces (BadBlockType / BadValType /
  NotImplemented).
- The remaining 9 likely cluster around assert_invalid /
  assert_trap shapes the runner partially supports.

**Next — 9.9-d-6 (D-061 discharge)**: extend
`populateShapeTags` (`src/engine/codegen/shared/regalloc.zig`)
to (a) trigger `any_simd = true` when the function signature
or local types contain v128, and (b) account for `local.get`
/ `local.tee` pushes in the vreg-numbering walk, tagging the
produced vreg with the local's type. This unblocks
`simd_select.0` end-to-end exercising the 9.9-d-5 emit code.

Subsequent §9.9 chunks per ADR-0045:
- 9.9-d-7: investigate residual 21 value-mismatches.
- 9.9-e: v128 PARAM marshal per ADR-0046 (unblocks multi-arg
  spec assertions like simd_select).
- 9.9-f: scale to FP arith + compares (heavy 9k+ files).
- 9.9-g: aggregate `test-spec-simd` into `test-all`; flip §9.9 [x].

After §9.9: §9.10 (smoke benches + gap analysis), §9.11
(audit + SHA backfill), §9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-061** (populateShapeTags vreg-numbering gap) — `now`;
  9.9-d-6 discharge target.
- **D-055** (x86_64 prologue inject) — blocked-by D-052 prologue
  extract.
- **D-057** (op_simd.zig hard-cap, now ~4442 LOC) — blocked-by
  ADR for source-split landing. Discharge requires ADR mirror
  of ADR-0030; deferred until §9.7 row close.
- 10 `blocked-by:` rows: D-007/D-010/D-016/D-018/D-020/D-021/
  D-022/D-026/D-028/D-052 — barriers all hold this resume.

Closed Phase 8b artefacts (preserved for Phase 12 + Phase 15)
live in git: ADRs 0035-0040, lessons in `.dev/lessons/INDEX.md`,
code in `src/ir/coalesce/`, regalloc.zig LIFO free-pool,
`src/engine/codegen/aot/`. `git log` is authoritative.

**Phase**: Phase 9 (SIMD-128, ADR-0041 — SSE4.2 baseline).
§9.5 [x] (ARM64 NEON pt 1), §9.6 [x] (ARM64 NEON pt 2),
§9.7 [x] (x86_64 SSE4.1+SSE4.2; 9.7-a..bb landed),
§9.8 [x] (scope absorbed per ADR-0044),
§9.9 in-flight (9.9-a..c + 9.9-d-1..5 landed; 9.9-d-6 NEXT —
populateShapeTags vreg-numbering gap / D-061 discharge).
**Branch**: `zwasm-from-scratch`。
