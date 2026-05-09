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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..an landed); **9.7-ao NEXT**

9.7-an: x86_64 i8x16.popcnt via SSSE3 PSHUFB-LUT (1 op, 11-instr
recipe + 2 consts via extra_consts). Added reusable helpers
`lookupOrAppendExtraConst` + `emitConstLoad` for future const-pool
consumers. Total SIMD ops handled: 182.

**9.7-ao NEXT** — bundle of remaining const-pool consumers using
the new extra_consts machinery and shared helpers:
- `i32x4.trunc_sat_f64x2_u_zero` (1 op, ~7 instr, 2 consts:
  UINT_MAX_f64-broadcast + 0x1.0p+52 mantissa-trick)
- `f64x2.convert_low_i32x4_u` (1 op, ~3 instr, 1-2 consts:
  shared 0x1.0p+52 mantissa magic + sign-flip if needed)
- `i32x4.extadd_pairwise_i16x8_u` (1 op, ~4 instr, 2 consts:
  sign-flip XOR mask + correction add)

Same handler shape (single-input v128 → v128) and same
const-pool dispatch infrastructure. Survey to confirm exact
recipes from cranelift `lower.isle:5069-5093` (trunc_sat_u),
`lower.isle:3775-3779` (convert_low_u), `lower.isle:4032-4071`
(extadd_pairwise_u). Bundle 3 ops in one chunk.

Subsequent: 9.7-ap (i8x16.shuffle — needs derived a-mask/b-mask
plumbing extension; ADR-grade decision), 9.7-aq
(i32x4.trunc_sat_f32x4_u — needs 3 scratch xmms; ADR-grade
scratch-budget decision). Phase 7 close-out approaching.

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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..an landed; 9.7-ao NEXT).
**Branch**: `zwasm-from-scratch`。
