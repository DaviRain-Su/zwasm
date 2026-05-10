# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.9 row — Phase 9 active.
3. `.dev/debt.md` — D-063 / D-071 (`now`) + D-070 / D-065 + 11 `blocked-by:` rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/decisions/0041_simd_128_design.md` (SSE4.2 baseline).
6. **`.dev/decisions/0049_defer_windowsmini_to_phase_close_batch.md`**
   — gate policy: per-chunk gate is Mac + OrbStack only;
   windowsmini reconciles at Phase boundaries. Effective
   from 2026-05-11.

## Current state — Phase 9 / §9.9 in-flight; **9.9-g-13 NEXT — D-071 part (b) IntCmp dst==lhs alias OR i8x16.popcnt PSHUFB recipe debug OR i64x2.mul x86_64 PMULUDQ debug**

9.9-g-12 (`<pending-sha>`): x86_64 `emitV128IntCmpSigned` alias
fix — same shape as 9.9-g-11's three helpers. OrbStack
simd_assert: **114 → 79 FAIL (-35)**. Cleared most
simd_i*x*_cmp residuals (52 → 16). Mac aarch64 unchanged at
11263/4.

**Mac aarch64 simd_assert_runner**: 11263 PASS / **4 FAIL** /
2476 SKIP (over 26 manifests; unchanged).

**OrbStack simd_assert_runner**: ~11200 PASS / **79 FAIL** /
~varying SKIP. Categorized in D-071.

Residual fails (cross-host):
- simd_const call_indirect Trap ×2 (D-063, both hosts).
- simd_const.388 BadValType (Mac + OrbStack; parse-side gap).
- simd_boolean.0 StackUnderflow (D-067 bitmask validator-shape;
  both hosts).
- OrbStack-only: 79 (D-071 buckets a/b/c/d).

**Next 9.9-g-13 candidates** (in priority order):
- **D-071 part (c)**: IntCmpSigned/Unsigned `dst == lhs` alias
  (the `.ge/.le` arms read lhs after dst is overwritten by
  min/max or PCMPGT). Mechanical fix. Targets ~16 fails.
- **D-071 part (b)**: `i8x16.popcnt` x86_64 PSHUFB synthesis
  debug. Targets ~25 fails.
- **D-071 part (a)**: `i64x2.mul` x86_64 PMULUDQ debug.
  Targets ~27 fails.
- **D-067 bitmask family** — wire validator + lower + ARM64
  emit synthesis (const-pool extension OR GPR-detour design
  choice).
- **Aggregate test-spec-simd into test-all** with allowlist
  (preventive — avoids future silent x86_64 simd regressions).

After §9.9 closes: §9.10 (smoke benches + gap analysis), §9.11
(audit + SHA backfill), §9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-063** (simd_const call_indirect v128 Trap) — `now`.
- **D-071** (x86_64 SIMD residuals: i64x2.mul + i8x16.popcnt
  + IntCmp dst==lhs alias + lane) — `now`. 79 OrbStack FAILs.
- **D-070** (bitselect/select alias risk; mirror of D-066) —
  blocked-by 3-v128-param runner dispatch + corpus assertion.
- **D-065** (arm64/inst_neon.zig 2076 LOC > 2000 cap) —
  blocked-by ADR for source-split.
- **D-055** (x86_64 prologue inject) — blocked-by D-052.
- **D-057** (x86_64 op_simd.zig 4442 LOC hard-cap) —
  blocked-by ADR for source-split landing.
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
§9.9 in-flight (9.9-a..c + 9.9-d-1..7 + 9.9-e-1..2 +
9.9-f-1..8 + 9.9-g-1..12 landed; 9.9-g-13 NEXT).
**Branch**: `zwasm-from-scratch`。
