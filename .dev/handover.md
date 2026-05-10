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

## Current state — Phase 9 / §9.9 in-flight; **9.9-f-2 NEXT — block-type decoder v128 widening (unblocks simd_bitwise.17 + simd_const.386 BadBlockType) OR scale to next fixture (simd_f32x4_arith / simd_i32x4_arith)**

9.9-f-1 (`b7fe37ee`): scaled corpus to simd_bitwise; 5 structural
changes — (v128,v128)→v128 entry helper + runner dispatch arm;
validator split for prefix-FD 77 (unop) + 82 (3-pop bitselect);
lower-side wiring for 78..82; ARM64 NEON emit handlers for
v128.{not,and,or,xor,andnot,bitselect}; 4 new NEON encoders
(encAnd16B, encBic16B, encEor16B, encMvn16B).

**Mac aarch64 simd_assert_runner totals after 9.9-f-1**:
**381 PASS** (was 257, +124) / **4 FAIL** (was 3, +1) /
338 SKIP. Tests: 1552/1564 (+4 encoder tests). OrbStack
1536/1564.

Residual 4 fails:
- simd_bitwise.17 BadBlockType — `block (result v128)` shape
- simd_const.386 BadBlockType — same family
- simd_const.388 BadValType — separate
- simd_const.389 NotImplemented — separate

**Next — 9.9-f-2**: investigate the BadBlockType failure
shape. Likely the block-type decoder (`parse/sections.zig`
or `validate/validator.zig`) doesn't accept v128 as a valid
block result type. Single-line fix candidate. Followup is
9.9-f-3+: scale to simd_f32x4_arith / simd_i32x4_arith /
etc. with similar (v128, v128) → v128 binop shapes.

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
§9.9 in-flight (9.9-a..c + 9.9-d-1..7 + 9.9-e-1..2 + 9.9-f-1
landed; 9.9-f-2 NEXT — BadBlockType / v128 block result).
**Branch**: `zwasm-from-scratch`。
