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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..v landed); **9.7-w NEXT**

9.7-v: x86_64 i8x16.shl + i8x16.shr_u inline-mask synthesis
(2 ops). encPsrlwImm new encoder + 9-/10-instr recipes via
PSLLW/PSRLW + PSHUFB byte-0 broadcast. Avoids const-pool
dep at cost of ~5 extra instr per call. Total SIMD ops
handled: 118.

**9.7-w NEXT** — i8x16.shr_s synthesis (1 op).
Cranelift's recipe (`lower.isle:846+`) uses byte→word
sign-extension via PUNPCKLBW + PUNPCKHBW (interleaving
with sign-mask scratch), then PSRAW on each half by c,
then PACKSSWB to compress back. Structurally different
from shl/shr_u (no AND-mask path).

Likely 2 new encoders (encPunpcklbw + encPunpckhbw) +
~12-15 instr handler. Sign-extension trick: PXOR(zero) +
PCMPGTB(zero, src) gives sign-bit mask; PUNPCKLBW(src,
sign_mask) interleaves to produce signed-extended words.
~150 src + ~80 test, no ADR.

Subsequent: 9.7-x+ (conversion + narrow/extend + shuffle
PSHUFB), 9.7-y (abs/neg via PXOR sign-mask synthesis),
9.7-z (v128.const + ADR-0042 const-pool finalisation).

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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..v landed; 9.7-w NEXT).
**Branch**: `zwasm-from-scratch`。
