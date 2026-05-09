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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..aq landed); **9.7-ar NEXT**

9.7-aq: x86_64 i32x4.extadd_pairwise_i16x8_u (1 op, 11-instr
inline-synth via sign-flip XOR + PMADDWD+1 + bias-correction).
Closes the extadd_pairwise family across all 4 variants. 1 new
encoder encPsllwImm. No const-pool dep. Total SIMD ops handled:
186.

**9.7-ar NEXT** — `i8x16.shuffle` (1 op). Cranelift's recipe
(`lower.isle:4710+`): PSHUFB(src1, a_mask) | PSHUFB(src2, b_mask)
where a_mask + b_mask are DERIVED from the original Wasm mask:
a_mask[i] = mask[i] if mask[i] < 16 else 0x80; b_mask[i] =
mask[i] - 16 if mask[i] >= 16 else 0x80. Structural challenge:
ADR-0042's per-instance simd_consts is populated by lower.zig
with the ORIGINAL mask, but x86_64 needs 2 derived masks.
Three resolution paths:
(a) Modify lower.zig to store derived masks for shuffle —
    changes lower contract used by ARM64.
(b) Add x86_64 emit-time derivation: handler reads original
    mask from func.simd_consts[const_idx], derives 2 masks,
    appends to extra_consts. Cleanest — matches existing
    extra_consts dedup pattern.
(c) Per-arch lower hook to emit derived masks at lower-time.
**Recommend (b)** — minimal change, no cross-arch impact.
Recipe: ~6 instr (2 MOVUPS-RIP-rel const loads + PSHUFB pair
+ POR-merge), 2 derived consts per call site (no dedup since
masks are per-instance).

Subsequent: 9.7-as (i32x4.trunc_sat_f32x4_u — needs 3 scratch
xmms; ADR-grade scratch-budget extension OR fall back to
spilling tmp to stack). Phase 7 close-out approaching:
~2 chunks until 7.13 hard gate.

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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..aq landed; 9.7-ar NEXT).
**Branch**: `zwasm-from-scratch`。
