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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..i [x]); **9.7-j NEXT**

9.7-i landed at bab7c888: f32x4 lane access trio (splat /
extract / replace). Adds encInsertps (SSE4.1 3A 21 /r ib);
splat + extract reuse encPshufd (PSHUFD on FP-domain data is
bit-identical to integer-domain shuffle). Total SIMD ops
handled: 27.

Three-host gate at bab7c888: Mac unit 1394/0/12 + gates ✓;
OrbStack at known D-054 baseline (211/1/20 + 1378/1406);
windowsmini full green (212/0/20 + every runner green).

**9.7-j NEXT** — f64x2 lane access trio. Encoders likely needed:
- f64x2.splat: MOVDDUP (F2 0F 12 /r) for the low-qword broadcast,
  OR reuse encPunpcklqdq with self-source (already have it).
- f64x2.extract_lane: lane=0 trivial (MOVAPS dst, src — already
  have encMovapsXmmXmm); lane=1 needs SHUFPD or MOVHLPS or
  PSHUFD with imm 0x4E (swap qwords). encPshufd works for the
  qword-as-2-dwords interpretation.
- f64x2.replace_lane: MOVAPS preamble + SHUFPD or MOVLHPS /
  MOVHLPS / encInsertps-equivalent (UNPCKLPD / UNPCKHPD trick).
  May want SHUFPD (66 0F C6 /r ib) — new encoder.

Step 0 will scope. Likely ~150-200 LOC.

Subsequent: 9.7-k (compare family — PCMPEQ*, PCMPGT* int + CMPPS
/ CMPPD FP), 9.7-l (FP arith ADDPS/PD/MULPS/DIVPS/SUBPS/PD),
9.7-m (FP unary abs/neg/sqrt + min/max/pmin/pmax), 9.7-n (int
compare extras + select / and / or / xor / not / bitselect),
9.7-o (conversion + narrow/extend + shuffle PSHUFB),
9.7-p (v128.const via ADR-0042 const-pool with x86_64
RIP-relative LEA + MOVDQU).

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
