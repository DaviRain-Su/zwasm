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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..n landed); **9.7-o NEXT**

9.7-n: x86_64 unsigned compares lt_u/gt_u/le_u/ge_u for
i8x16/i16x8/i32x4 (12 ops). 6 new encoders (PMAXUB/PMINUB
SSE2; PMAXUW/PMINUW/PMAXUD/PMINUD SSE4.1) + new helper
`emitV128IntCmpUnsigned(encoder_minmax, encoder_pcmpeq, kind)`
following cranelift's PMINU/PMAXU + PCMPEQ recipe
(`lower.isle:2016-2080`). 12 1-line wrappers + 12 dispatch
arms + 4 path-coverage tests. Total SIMD ops handled: 66.

**9.7-o NEXT** — FP compare ops eq/ne/lt/gt/le/ge for f32x4
+ f64x2 (12 ops). Cranelift recipe (`lower.isle` around fcmp
arms) emits CMPPS/CMPPD with imm8 predicate codes:
- 0x00 EQ_OQ (eq), 0x04 NEQ_UQ (ne), 0x01 LT_OS (lt),
  0x02 LE_OS (le), 0x06 NLE_US (gt), 0x05 NLT_US (ge)
  per Intel SDM Vol 2 CMPPS/CMPPD (SSE / SSE2 baseline).
- Single instruction CMPPS xmm,xmm,imm8 (SSE 0F C2 /r ib);
  CMPPD same opcode with 66 prefix (SSE2).
Likely shape: 1 new encoder family `encCmppsImm` /
`encCmppdImm` (or unified factor) + 1 new helper
`emitV128FpCmp(encoder, predicate)` + 12 wrappers. ~120 src
+ ~120 test. No ADR needed.

Subsequent: 9.7-p+ (FP arith ADDPS/PD/MULPS/PD/DIVPS/PD/
SQRTPS/PD/MINPS/PD/MAXPS/PD), 9.7-q+ (bitwise ops + select),
9.7-r+ (conversion + narrow/extend + shuffle PSHUFB),
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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..n landed; 9.7-o NEXT).
**Branch**: `zwasm-from-scratch`。
