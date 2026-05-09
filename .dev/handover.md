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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..u landed); **9.7-v NEXT**

9.7-u: x86_64 i64x2.shr_s synthesis (1 op). encPsubq new
encoder + 9-instr inline-mask recipe (PCMPEQB+PSLLQ-imm
sign-bit mask synthesis avoids const-pool dependency).
Total SIMD ops handled: 116. i8x16 shifts (3 ops) still
deferred.

**9.7-v NEXT** — i8x16 shifts shl/shr_u/shr_s (3 ops).
Cranelift's recipes need count-dependent AND-mask byte
broadcast. Two paths:

- **(A)** Inline-synth via SHL r8 + PSHUFB-broadcast.
  Steps: scalar SHL r8 to compute byte-mask value, MOVD
  scratch_xmm, MOVD ctrl_xmm + PXOR ctrl_xmm,ctrl_xmm
  to zero-control, PSHUFB scratch_xmm,ctrl_xmm to
  broadcast byte 0 to 16 lanes, then PSLLW/PSRLW + PAND.
  ~12-14 instr per shift; no const-pool dep.
- **(B)** const-pool 8×16-byte mask table + runtime
  index lookup. ADR-0042 plumbing required first.
  Cleaner emit (~5 instr) but blocks on const-pool.

Recommendation: go (A) inline — keeps 9.7-* chunks self-
contained and mirrors 9.7-u's same trade-off. ~250 src +
~100 test. Lesson note may be warranted on the const-pool
deferral pattern.

Subsequent: 9.7-w+ (conversion + narrow/extend + shuffle
PSHUFB), 9.7-x (abs/neg via PXOR sign-mask), 9.7-y
(v128.const + ADR-0042 const-pool finalisation).

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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..u landed; 9.7-v NEXT).
**Branch**: `zwasm-from-scratch`。
