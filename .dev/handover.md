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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..d [x]); **9.7-e NEXT**

9.7-d landed at c15482e9: i64x2.mul synthesis via the canonical
PMULUDQ + shift/add idiom (11-instruction sequence, scratch
reuses XMM14/XMM15 fp_spill_stage_xmms — no ABI change). Adds
`encPmuludq`, `encPsrlqImm`, `encPsllqImm` encoders + new
`encSsePackedShiftImmGroup` factor for the `66 0F 73 /<group> ib`
/X-group form. Total SIMD ops handled: 11. Edge fixtures
deferred to 9.7-e (need v128 producer first).

Three-host gate at c15482e9: Mac unit 1357/0/12 + zone/file_size/
spill/lint ✓; OrbStack at known D-054 baseline (211/1/20);
windowsmini full green (212/0/20 spec_assert + every other
runner green).

**9.7-e NEXT** — lane access primitives. End-to-end JIT-execution
fixtures need v128 producers (splat / const) AND consumers
(extract_lane). Bundle candidates:
- splat family (i8x16/i16x8/i32x4/i64x2/f32x4/f64x2) via PINSR* +
  PSHUFD broadcast (or MOVD + PSHUFD for i32x4-style splats).
- extract_lane / replace_lane (signed + unsigned variants for
  narrow lanes) via PEXTRB/W/D/Q + PINSRB/W/D/Q.
- v128.const via the const-pool + post-emit fixup pass already
  designed for ARM64 in ADR-0042 (mirror the load-relative
  pattern but with x86_64 RIP-relative LEA + MOVDQU).

Step 0 survey should partition: which primitives bundle in
9.7-e (the simpler splat + scalar-lane variants) and which spin
out into 9.7-f / 9.7-g (v128.const if non-trivial; replace_lane
if encoder pressure). Once 9.7-e lands, ALL 11 prior SIMD ops
become end-to-end testable via spec/wast fixtures + edge_cases
boundary fixtures (cross-lane carry for i64x2.mul, NaN-prop for
f32x4.add, etc.) can finally land.

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
