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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..h [x]); **9.7-i NEXT**

9.7-h landed at 9659a6df: integer splat trio (i8x16 / i16x8 /
i64x2). Adds encPxor (SSE2 0F EF), encPshufb (SSSE3 0F 38 00),
encPshuflw (F2 0F 70 /r ib), encPunpcklqdq (66 0F 6C /r). i8x16
uses XMM14 scratch for the all-zero PSHUFB ctrl mask. Total SIMD
ops handled: 24 (= all 6 splat shapes are now wired except FP).

Three-host gate at 9659a6df: Mac unit 1389/0/12 + gates ✓;
OrbStack at known D-054 baseline (211/1/20 + 1373/1401);
windowsmini full green (212/0/20 + every runner green).

**9.7-i NEXT** — FP lane access (f32x4 / f64x2 splat + extract +
replace). XMM-source semantics differ from int paths:
- f32x4.splat: SHUFPS xmm_dst, xmm_src, 0x00 (broadcasts lane 0).
  Or PSHUFD via integer-domain alias.
- f64x2.splat: MOVDDUP (F2 0F 12 /r) — broadcasts low qword to
  both 64-bit lanes. SSE3.
- f32x4.extract_lane: lane=0 → MOVAPS dst, src; otherwise PSHUFD
  with imm8 selector to bring the lane into position 0. Result
  is XMM (f32 in low 32).
- f64x2.extract_lane: lane=0 → MOVAPS; lane=1 → MOVHLPS or
  SHUFPD with imm.
- f32x4.replace_lane: INSERTPS (66 0F 3A 21 /r ib) — SSE4.1.
  Imm8 encodes both src lane (bits 6-7) and dst lane (bits 4-5).
- f64x2.replace_lane: MOVAPS preamble + MOVLHPS / MOVHLPS /
  SHUFPD with appropriate imm depending on lane.

Likely ~250-350 LOC. Step 0 should partition: bundle all 6 FP
lane ops, OR split splat (3) + extract+replace (3).

Subsequent: 9.7-j (compare family — PCMPEQ*, PCMPGT*), 9.7-k (FP
arith ADDPS/ADDPD/MULPS/DIVPS), 9.7-l (FP compare CMPPS/PD),
9.7-m (conversion + shuffle PSHUFB + v128.const via ADR-0042).

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
