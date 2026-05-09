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

## Current state — Phase 9 / §9.7 in-flight (9.7-a + 9.7-b + 9.7-c [x]); **9.7-d NEXT**

9.7-c landed at 0fe5413d: native packed integer multiply (2 ops).
Extended `encSsePackedIntBinopExt(escape2, opcode, ...)` to cover
the SSE4.1 secondary-escape form (66 0F 38 ..); added `encPmullW`
(SSE2 i16x8.mul) + `encPmullD` (SSE4.1 i32x4.mul, **first
SSE4.1-exclusive op** zwasm v2 emits per ADR-0041). Handlers
reuse 9.7-b's `emitV128IntBinop` helper without ABI changes.
Total SIMD ops handled: 10.

Three-host gate at 0fe5413d: Mac unit 1349/0/12 + zone/file_size/
spill/lint ✓; OrbStack at known D-054 baseline (211/1/20); v128
spill remains UnsupportedOp pending 16-byte MOVDQU helpers
(post-9.7-d task).

**9.7-d NEXT** — i64x2.mul synthesis. No native SSE4.1 form
(VPMULLQ is AVX-512-gated, beyond ADR-0041 baseline). Cranelift
idiom uses PMULUDQ (32×32→64) lane-decomposition with PSHUFD lane
swaps, PSLLQ shifts, and PADDQ accumulate (~8-12 instructions).
Per p9-9.7-c-survey.md: ~150 LOC, may need 1-2 SIMD scratches
from spill-stage XMM14/XMM15 (or a dedicated SIMD scratch —
ADR-grade if it changes allocatable_xmms). Step 0 survey for
9.7-d should pin down the exact instruction sequence + scratch
reservation strategy + whether it warrants a new ADR.

Subsequent chunks: 9.7-e (lane access — splat / extract_lane /
replace_lane via PSHUFD + PINSRB/W/D + PEXTRB/W/D), 9.7-f
(compare family), 9.7-g (FP arith), 9.7-h (FP compare), 9.7-i
(conversion + shuffle). Sub-row plan refines as each chunk's
Step 0 survey lands.

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
