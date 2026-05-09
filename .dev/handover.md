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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..ae landed); **9.7-af NEXT**

9.7-ae: x86_64 inline-synth FP convert + trunc-sat (2 of 6
candidate ops). f32x4.convert_i32x4_u (11-instr split-and-
recombine) + i32x4.trunc_sat_f32x4_s (9-instr NaN-mask +
XOR-fix). 4 new encoders (Cvttps2dq, PsradImm, Andps,
Andpd). 4 const-pool-dependent variants deferred to 9.7-ag.
Total SIMD ops handled: 162.

**9.7-af NEXT** — i*x*.popcnt + i16x8.q15mulr_sat_s +
i32x4.dot_i16x8_s + i*x*.extadd_pairwise_* (~6 ops). Most
are inline-synthesisable: popcnt via Mula nibble-LUT or
PSHUFB-table or shift-and-add (no const-pool with
shift-and-add; const-pool with PSHUFB); q15mulr_sat via
PMULHRSW (SSE4.1, 1 instr); dot_i16x8_s via PMADDWD (SSE2,
1 instr); extadd_pairwise via PMADDUBSW (SSSE3) +
PMADDWD. Bundle most into one chunk; popcnt may split if
const-pool dep tipping.

Subsequent: 9.7-ag (ADR-0042 const-pool plumbing + 4
deferred 9.7-ae u-variants + i8x16.shuffle + v128.const),
9.7-ah+ (any remaining misc ops; phase 7 close-out at
9.7-ax pending).

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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..ae landed; 9.7-af NEXT).
**Branch**: `zwasm-from-scratch`。
