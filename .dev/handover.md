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

## Current state — Phase 9 / §9.9 in-flight; **9.9-f-7 NEXT — wire ARM64 emit dispatch for missing int arith ops (i8x16/i16x8 add/sub already-existing-helpers + new neg/abs/popcnt handlers for all 4 shapes)**

9.9-f-6 (`56a4209c`): scaled corpus to f64x2/i32x4/i16x8/
i8x16/i64x2 arith (5 new fixtures, ~7400 assertions); split
validator's 94..211 range into per-op unop/binop arms; wired
19 int-arith sub-opcodes in lower.zig.

**Mac aarch64 simd_assert_runner totals after 9.9-f-6**:
**2893 PASS** (was 1628, +1265) / **11 FAIL** (was 4, +7) /
2176 SKIP. Tests: 1552/1564 Mac, 1536/1564 OrbStack.

Residual 11 fails:
- 8× UnsupportedOp from int-arith fixtures (i8x16, i16x8,
  i32x4 modules .0/.12 + i8x16.9): ARM64 emit dispatch
  missing for several ops.
- 2× simd_const call_indirect Trap (D-063)
- simd_const.388 BadValType (parse-side gap)

**Next — 9.9-f-7**: wire ARM64 emit dispatch + emit handlers:
- Already-existing helpers needing dispatch: `emitI8x16Add`,
  `emitI8x16Sub`, `emitI16x8Add`, `emitI16x8Sub`. Add 4
  dispatch arms in arm64/emit.zig.
- New emit handlers needed (simple SIMD unops): i8x16.{neg,
  abs,popcnt}, i16x8.{neg,abs}, i32x4.{neg,abs}, i64x2.{neg,
  abs}. Use NEG / ABS / CNT NEON instructions; encode + add
  helpers in inst_neon.zig + op_simd.zig.
- Likely +many-thousand PASS once dispatch wired.

After §9.9: §9.10 (smoke benches + gap analysis), §9.11
(audit + SHA backfill), §9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-063** (simd_const.386 call_indirect v128 Trap) — `now`;
  deferred from 9.9-f-3.
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
§9.9 in-flight (9.9-a..c + 9.9-d-1..7 + 9.9-e-1..2 + 9.9-f-1..6
landed; 9.9-f-7 NEXT — wire ARM64 emit dispatch + new neg/abs
handlers).
**Branch**: `zwasm-from-scratch`。
