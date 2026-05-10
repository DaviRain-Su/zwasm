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

## Current state — Phase 9 / §9.9 in-flight (9.9-a..c + 9.9-d-1 landed); **9.9-d-2 ARM64 v128.load bounds-check + missing emit handlers NEXT**

9.9-d-1 (`c0103336`): discharge BadValType + IR-liveness
UnsupportedOp clusters. `src/parse/sections.zig:readValType`
accepts 0x7B → `.v128`; the validator already handled v128 in
type-stack rules per §9.3, so parse-side gate-keep was the
residual gap. `src/ir/analysis/liveness.zig:stackEffect` gains
entries for the full v128 op catalogue (~135 LOC, mirrored
from `src/engine/codegen/shared/regalloc.zig:382-628` shape-tag
table + `zir.zig:184-288` ZirOp enum). Mac + OrbStack test-all
green; windowsmini gate fired after push.

**Per-manifest after 9.9-d-1 (Mac aarch64)**:
- simd_address: 2 PASS, 3 FAIL, 44 SKIP
- simd_select:  0 PASS, 1 FAIL, 6 SKIP
- simd_const:  60 PASS, 158 FAIL, 232 SKIP
- simd_align:  SEGV mid-run on simd_align.90/91 v128.load
  invocation. ARM64 `emitV128Load` (`src/engine/codegen/arm64/
  op_simd.zig:52`) uses `LDR Q,[X<wn>,#imm]` directly without
  the bounds-checked vm_base translation that scalar
  `op_memory.emitMemOp` (and x86_64 `v128MemPrologue` per
  §9.7-ax) perform — wasm-relative addr is treated as host
  pointer, dereferences SEGV.

**Next — 9.9-d-2**: bring ARM64 v128.load + v128.store up to
parity with scalar memOp shape (X28 = vm_base / X27 = mem_limit
prologue + bounds-check + B.HS trap-stub fixup, then
`LDR Q, [X28, X16]`). Likely involves either factoring the
existing `emitMemOp` to be access_size-parametric or a sibling
`emitV128MemOp` helper. Closes the SEGV blocker.

**Subsequent 9.9-d-N chunks**: ARM64 emit gaps surfaced by
the residual UnsupportedOp cluster (~35 fails on Mac):
- v128.load8x8_{s,u} / load16x4_{s,u} / load32x2_{s,u} (extend)
- v128.load{8,16,32,64}_splat (splat-from-mem)
- v128.load{8,16,32,64}_lane / store{8,16,32,64}_lane
- v128.load{32,64}_zero
- select on v128 (simd_select.0)
Plus simd_const's 158 value-mismatch fails (likely f32x4/f64x2
NaN canonicalization or specific lane encodings — analyse case
by case).

Subsequent §9.9 chunks per ADR-0045:
- 9.9-e: v128 PARAM marshal per ADR-0046 (unblocks multi-arg
  spec assertions like simd_select).
- 9.9-f: scale to FP arith + compares (heavy 9k+ files).
- 9.9-g: aggregate `test-spec-simd` into `test-all`; flip §9.9 [x].

After §9.9: §9.10 (smoke benches + gap analysis), §9.11
(audit + SHA backfill), §9.12 (open Phase 10).

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
§9.7 [x] (x86_64 SSE4.1+SSE4.2; 9.7-a..bb landed),
§9.8 [x] (scope absorbed per ADR-0044),
§9.9 in-flight (9.9-a..c + 9.9-d-1 landed; 9.9-d-2 NEXT —
ARM64 v128.load bounds-check translation).
**Branch**: `zwasm-from-scratch`。
