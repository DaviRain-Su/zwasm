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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..j [x]); **9.7-k NEXT**

9.7-j landed at 28ec5a4d: f64x2 lane access trio. Adds
encMovsdXmmXmm (F2 0F 10 /r mod=11 — reg-reg form preserves
upper 64) + encMovlhps (0F 16 /r). Splat + extract reuse
encPshufd with imm 0x44 (low qword broadcast) / 0xEE (high
qword to position 0). Replace lane=0 uses MOVSD reg-reg
(preserves high), lane=1 uses MOVLHPS. Total SIMD ops handled:
30 — full splat / extract / replace surface for all 6 shapes.

Three-host gate at 28ec5a4d: Mac unit 1402/0/12 + gates ✓;
OrbStack at known D-054 baseline (211/1/20 + 1386/1414);
windowsmini full green (212/0/20 + every runner green).

**9.7-k NEXT** — int compare family. Wasm ops:
- i8x16/i16x8/i32x4 eq/ne/lt_s/lt_u/gt_s/gt_u/le_s/le_u/ge_s/ge_u
  = 30 ops. i64x2 eq/ne/lt_s/gt_s/le_s/ge_s = 6 ops (no _u for i64x2
  per spec). Total 36 int compare ops.

Native SSE2 / SSE4.1 instructions:
- PCMPEQB / PCMPEQW / PCMPEQD (SSE2): equal compare per lane.
- PCMPEQQ (SSE4.1): i64x2 equal.
- PCMPGTB / PCMPGTW / PCMPGTD (SSE2): signed greater-than.
- PCMPGTQ (SSE4.2 — beyond ADR-0041 baseline!): i64x2 signed gt.

i64x2.gt_s needs synthesis when SSE4.2 is unavailable. Cranelift
idiom: PCMPGTD + AND/swap tricks; or PSUBQ-based MSB extraction.

Unsigned compares synthesise via signed: a <_u b ⇔ (a ^ MSB) <_s
(b ^ MSB) for integer types. Or use PMINUB / PMAXUB / PMINUW /
PMAXUW for some cases. Cranelift prefers PXOR-with-sign-mask +
PCMPGT.

Likely partition: 9.7-k (eq/ne family — clean PCMPEQ + NOT for
ne), 9.7-l (signed lt/gt/le/ge), 9.7-m (unsigned lt/gt/le/ge
synthesis), 9.7-n (i64x2 signed compares with SSE4.2 fallback).
4 sub-chunks. Step 0 will pin down i64x2.gt_s synthesis +
unsigned compare strategy + ADR-grade decisions if any.

Subsequent: 9.7-o+ (FP compare CMPPS/PD), 9.7-p+ (FP arith),
9.7-q+ (bitwise ops + select), 9.7-r+ (conversion + narrow/extend
+ shuffle PSHUFB), 9.7-s (v128.const via ADR-0042 const-pool).

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

**Phase**: Phase 9 (SIMD-128, ADR-0041). §9.5 [x] (ARM64 NEON pt 1),
§9.6 [x] (ARM64 NEON pt 2), §9.7 NEXT (x86_64 SSE4.1).
**Branch**: `zwasm-from-scratch`。
