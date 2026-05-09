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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..p landed); **9.7-q NEXT**

9.7-p: x86_64 FP arithmetic add/sub/mul/div + sqrt for f32x4
+ f64x2 (10 ops). 10 new encoders (ADDPS/SUBPS/MULPS/DIVPS/
SQRTPS SSE no-66 + PD variants SSE2 with 66). New factor
`encSseFpPsBinop` for PS shape; PD reuses
`encSsePackedIntBinop`. 8 binary ops via emitV128IntBinop +
2 unary sqrt via new emitV128FpUnop. f32x4/f64x2 min/max
deferred to 9.7-q (NaN-correction synthesis). Total SIMD
ops handled: 88.

**9.7-q NEXT** — f32x4 + f64x2 min/max with NaN-correction
synthesis (4 ops). SSE MINPS/MAXPS use "if unordered, return
src2" semantics that don't match Wasm's IEEE-754-2019
minimum/maximum (NaN-propagating, signed-zero-aware).
Cranelift's recipe (`lower.isle` F32X4/F64X2 fmin/fmax) is
~7 instructions: min1=MINPS(x,y), min2=MINPS(y,x), or=ORPS
(min1, min2), is_nan_mask=CMPPS(or, min2, UNORD), or2=ORPS
(or, is_nan_mask), nan_frac_mask=PSRLD(is_nan_mask, 10),
result=ANDNPS(nan_frac_mask, or2). For F64X2 same shape
with PD encoders + PSRLQ shift=13. 4 new encoders needed
(ORPS/ORPD/ANDNPS/ANDNPD; PSRLD/PSRLQ may already exist
from 9.7-d). 1 new helper `emitV128FpMinMax(...)` taking
the encoder family + scratch reg. ~150 src + ~80 test
(complex but mechanical). ADR optional — synthesis is
cranelift's published recipe, not a load-bearing decision.

Subsequent: 9.7-r+ (bitwise + select), 9.7-s+ (conversion +
narrow/extend + shuffle PSHUFB + abs/neg via const-pool),
9.7-t (v128.const via ADR-0042 const-pool).

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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..p landed; 9.7-q NEXT).
**Branch**: `zwasm-from-scratch`。
