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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..av landed); **9.7-aw i64x2.extract_lane NEXT**

9.7-av: 4 ops (commit `bd778bcf`) — f32x4/f64x2 × {pmin, pmax}
direct dispatch to MINPS/MAXPS/MINPD/MAXPD with operand swap.
The "pseudo-min/max needs synthesis" hypothesis was wrong: x86
MINPS's "return SRC on equal/NaN/both-zero" semantics align
exactly with Wasm pmin(c1,c2) when dst=c2, src=c1. New helper
emitV128FpPseudoBinop (operand-swapped emitV128IntBinop). No
new encoders. Distinct from 9.7-q fmin/fmax (which DO need
10-13 instr canonical-min/max synthesis). 3-host green.

**Next — 9.7-aw**: i64x2.extract_lane (1 op). PEXTRQ (SSE4.1
3A 16 /r ib REX.W variant of PEXTRD) — XMM in ModR/M.reg, GPR
in r/m. Pattern mirrors 9.7-e's emitI32x4ExtractLane exactly,
just with REX.W bit set + 64-bit GPR target. New encoder
encPextrQ (likely 1 line via the existing PEXTR-* helper if
parametric on REX.W, else a sibling). Single-op chunk —
trivial.

After 9.7-aw: 9.7-ax+ for v128 memory ops (~22 ops:
load/store + load_lane/store_lane + splat/zero/extending).
Significant new infra: memory-addressing encoders (MOVDQU /
MOVDQA / MOVUPS / MOVSS / MOVSD memory forms), alignment
flag encoding, ZirOp payload that carries memarg (offset +
alignment). Likely 3-5 sub-chunks. Once those land, §9.7 row
+ §9.8 row (overlapping scope) close together via §18 ADR or
scope merge.

Subsequent: §9.9 (simd.wast wired in, fail=skip=0), §9.10
(smoke benches + gap analysis), §9.11 (audit + SHA backfill),
§9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-055** (x86_64 prologue inject) — blocked-by D-052 prologue
  extract.
- **D-057** (op_simd.zig hard-cap, now ~4070 LOC) — blocked-by
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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..av landed; 9.7-aw
NEXT; ~23 SIMD ops still unhandled — i64x2.extract_lane + 22
v128 memory ops — before §9.7 close).
**Branch**: `zwasm-from-scratch`。
