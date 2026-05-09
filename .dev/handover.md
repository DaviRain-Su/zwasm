# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.7 row — Phase 9 active.
3. `.dev/debt.md` — D-054 + D-055 + 9 other rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: simd compare ops, x86_64 SSE/PCMPGT idioms, ADR-0041 §5
   baseline rationale).
5. `.dev/decisions/0041_simd_128_design.md` (SSE4.2 baseline post-9.7-m
   amendment; §5 + Alternative E hold the rationale).
6. `private/notes/p9-9.7-m-survey.md` (gitignored; cranelift recipe +
   adoption data) — only if revisiting the SSE4.2 baseline call.

## Current state — Phase 9 / §9.7 in-flight (9.7-a..af landed); **9.7-ag NEXT**

9.7-af: x86_64 q15mulr_sat_s + dot_i16x8_s (2 ops). 2 new
encoders (PMULHRSW SSSE3 + PMADDWD SSE2). Both single-instr
via existing emitV128IntBinop. Total SIMD ops handled: 164.

**9.7-ag NEXT** — i16x8.extmul_{low,high}_i8x16_{s,u} (4 ops):
3-instr recipe per cranelift `lower.isle:1197-1285` —
PMULLW dst, src1, src2 (low halves) + PMULHW or PMULHUW tmp,
src1, src2 (high halves) + PUNPCKLWD or PUNPCKHWD dst, dst,
tmp. New encoders: PMULHW (SSE2 0F E5) + PMULHUW (SSE2 0F E4)
+ PUNPCKLWD (0F 61) + PUNPCKHWD (0F 69). Reuses XMM14
scratch. ~120 src + ~120 test, 4 new encoders.

Subsequent: 9.7-ah (i32x4.extmul_{low,high}_i16x8_{s,u} 4 ops,
similar shape with PMULLD already from 9.7-c), 9.7-ai
(i64x2.extmul_{low,high}_i32x4_{s,u} 4 ops, PMULDQ SSE4.1 +
PMULUDQ already from 9.7-d), 9.7-aj (ADR-0042 const-pool +
popcnt + 4 extadd_pairwise + 4 deferred 9.7-ae u-variants +
i8x16.shuffle + v128.const). Phase 7 close-out at 9.7-ax+
pending.

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-054** (OrbStack-only as-loop-broke) — Rosetta JIT-emulation
  artefact; baseline 211/1/20 carried as known.
- **D-055** (x86_64 prologue inject) — blocked-by D-052 prologue
  extract.
- 9 `blocked-by:` rows: D-007/D-010/D-016/D-018/D-020/D-021/D-022/
  D-026/D-028/D-052 — barriers all hold.

Closed Phase 8b artefacts (preserved for Phase 12 + Phase 15
reference) live in git: ADRs 0035-0040, lessons indexed in
`.dev/lessons/INDEX.md`, code in `src/ir/coalesce/`,
`src/engine/codegen/shared/regalloc.zig` (LIFO free-pool),
`src/engine/codegen/aot/`. No need to duplicate pointers here —
`git log` is the authoritative lookup.

**Phase**: Phase 9 (SIMD-128, ADR-0041 — SSE4.2 baseline post-9.7-m).
§9.5 [x] (ARM64 NEON pt 1), §9.6 [x] (ARM64 NEON pt 2),
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..af landed; 9.7-ag NEXT).
**Branch**: `zwasm-from-scratch`。
