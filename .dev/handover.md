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

## Current state — Phase 9 / §9.9 in-flight; **9.9-f NEXT — scale spec corpus to FP arith + compares (heavy 9k+ files); §9.9-g closes Phase 9**

9.9-d-7 (`d8fb4939`): two runner-side fixes:
1. `runner.applyActiveDataSegments` (new pub helper) mirrors
   `setupRuntime`'s data-init half; called from
   `simd_assert_runner.zig` after the existing memset.
   Unblocked 21 simd_address value-mismatches.
2. `regen_spec_simd_assert.sh` skips export-names-with-spaces
   (e.g. `v128.load align=16`) since the runner's directive
   parser splits on first space. Re-baked simd_align manifest
   flips 3 assert_returns from FAIL to SKIP.

**Mac aarch64 simd_assert_runner totals after 9.9-d-7**:
**257 PASS** (was 227, +30) / **3 FAIL** (was 36, -33) / 295 SKIP
(was 292). Remaining 3 fails: simd_const.386 BadBlockType,
.388 BadValType, .389 NotImplemented — validator/lower gaps,
not v128-codegen.

**Next — 9.9-f**: scale `regen_spec_simd_assert.sh`'s NAMES
list past the `simd_address / simd_align / simd_const /
simd_select` starter set to include FP arith + compares
(simd_f32x4_arith, simd_f64x2_arith, simd_f32x4_cmp, etc.).
~9k+ assertions across the upstream corpus. Iterative shape:
add a manifest, run, classify failures, fix where mechanical
(emit-arm gaps), file debt where structural.

After §9.9: §9.10 (smoke benches + gap analysis), §9.11
(audit + SHA backfill), §9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

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
§9.9 in-flight (9.9-a..c + 9.9-d-1..7 + 9.9-e-1..2 landed;
9.9-f NEXT — scale corpus to FP arith / compares).
**Branch**: `zwasm-from-scratch`。
