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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..w landed); **9.7-x NEXT**

9.7-w: x86_64 i8x16.shr_s sign-extension synthesis (1 op).
encPunpcklbw + encPunpckhbw new encoders + 11-instr recipe
(PCMPGTB sign-mask + byte→word extend + PSRAW × 2 +
PACKSSWB). Closes the i*x*.shift family (12 shift ops).
Total SIMD ops handled: 119.

**9.7-x NEXT** — integer extend low/high (12 ops):
i16x8.extend_{low,high}_i8x16_{s,u} + i32x4.extend_*_i16x8_*
+ i64x2.extend_*_i32x4_*. SSE4.1 has direct PMOVSXBW
/PMOVZXBW + PMOVSXWD/PMOVZXWD + PMOVSXDQ/PMOVZXDQ for low
half (4-byte interleaved memory→reg form, but reg-reg form
exists too taking low 8 bytes of src). For HIGH half, no
direct instruction; need PSRLDQ-shift + low-extend OR
PUNPCKHBW-style trick.

Cranelift uses PMOVSX*/PMOVZX* directly for low; for high
it uses PSHUFD(src, 0xEE) to swap high → low position then
PMOVSX/ZX. ~6 new encoders (PMOVSXBW/WD/DQ + PMOVZXBW/WD/DQ)
+ 12 wrappers. ~250 src + ~80 test, no ADR.

Subsequent: 9.7-y+ (narrow saturating + shuffle PSHUFB +
abs/neg sign-mask synthesis), 9.7-z (FP convert + trunc-
sat), 9.7-aa (v128.const + ADR-0042 const-pool finalisation).

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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..w landed; 9.7-x NEXT).
**Branch**: `zwasm-from-scratch`。
