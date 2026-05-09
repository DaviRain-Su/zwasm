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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..o landed); **9.7-p NEXT**

9.7-o: x86_64 FP compare eq/ne/lt/gt/le/ge for f32x4 + f64x2
(12 ops). 2 new encoders encCmpps (SSE 0F C2 /r ib, no 66
prefix) + encCmppd (SSE2 66 0F C2 /r ib) with imm8 predicate
per Intel SDM Vol 2A "CMPPS" Table 3-7. New helper
`emitV128FpCmp(encoder, imm8, swap_operands)` mirrors signed-
compare shape; cranelift's predicate selection
(`lower.isle:2149-2176`): eq=0/ne=4/lt=1/le=2 direct, gt/ge
swap+lt/le. Total SIMD ops handled: 78.

**9.7-p NEXT** — FP arithmetic for f32x4 + f64x2 (16 ops):
add/sub/mul/div/min/max/sqrt + abs/neg (where abs/neg are
unop). Encoders ADDPS/SUBPS/MULPS/DIVPS/MINPS/MAXPS/SQRTPS
(SSE 0F 58/5C/59/5E/5D/5F/51) + the PD variants (SSE2 with
66 prefix). abs/neg via PAND / PXOR with sign-mask constants
(needs const-pool plumbing per ADR-0042). Likely shape: 7-8
new binary encoders + 1-2 unary + emitV128FpBinop helper +
shape for abs/neg deferred to const-pool chunk (9.7-r). The
plain binary 7×2 = 14 ops (add/sub/mul/div/min/max/sqrt-as-
unop) might bundle; ~150 src + ~150 test. No ADR needed.

Subsequent: 9.7-q (bitwise + select v128.{not, and, or, xor,
andnot, bitselect, any_true, all_true}), 9.7-r+ (conversion
+ narrow/extend + shuffle PSHUFB + abs/neg via const-pool),
9.7-s (v128.const via ADR-0042 const-pool).

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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..o landed; 9.7-p NEXT).
**Branch**: `zwasm-from-scratch`。
