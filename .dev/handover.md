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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..r landed); **9.7-s NEXT**

9.7-r: x86_64 v128 bitwise ops + any_true (7 ops). 4 new
encoders (PAND/POR/PANDN SSE2; PTEST SSE4.1). v128.not 3-
instr synth; and/or/xor via emitV128IntBinop; andnot custom
2-instr (PANDN's negated-first-operand semantic); bitselect
5-instr PAND/PANDN/POR chain per cranelift; any_true PTEST +
SETNE + MOVZX. regalloc produces_vreg list extended for
5 v128 + 1 scalar new ops. Total SIMD ops handled: 99.

**9.7-s NEXT** — per-shape all_true + bitmask reductions
(8 ops): i8x16/i16x8/i32x4/i64x2.{all_true, bitmask}. all_true
via PCMPEQ_<lane>(xmm, zero) + PMOVMSKB + CMP all-set + SETE
or via PTEST + AND mask comparison. bitmask via PMOVMSKB
(i8x16 — direct; PSADBW or PMOVMSK*-equivalent for wider
lanes). Each shape needs distinct synthesis since the lane-
mask shapes differ. Likely: 1-2 new encoders (PMOVMSKB SSE2)
+ shape-specific synthesis helpers + 8 wrappers. ~250 src
+ ~120 test. No ADR.

Subsequent: 9.7-t+ (i*x* shifts shl/shr_s/shr_u; abs/neg via
PXOR sign-mask const-pool), 9.7-u+ (conversion + narrow/
extend + shuffle PSHUFB), 9.7-v (v128.const via ADR-0042
const-pool finalisation).

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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..r landed; 9.7-s NEXT).
**Branch**: `zwasm-from-scratch`。
