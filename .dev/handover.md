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

## Current state — Phase 9 / §9.9 in-flight (9.9-a..c + 9.9-d-1, 9.9-d-2 landed); **9.9-d-3 ARM64 v128 mem op gaps (load_extend / load_splat / load_zero / load_lane / store_lane / select_v128) NEXT**

9.9-d-2 (`c0fd94fb`): closes D-060. ARM64 `emitV128Load` /
`emitV128Store` rewritten to mirror `op_memory.emitMemOp`'s
prologue (ORR W16+offset-fold+ADD X17 access_size+CMP X27+
B.HI fixup) ending in `LDR/STR Q<vt>, [X28, X16]`. Private
`v128MemPrologue` helper in `arm64/op_simd.zig` for upcoming
mem op reuse. New encoders `encLdrQReg` / `encStrQReg` in
`inst_neon.zig` (Q-form reg-offset, verified against clang
assembler). simd_assert_runner runner completes without SEGV.

**Mac aarch64 simd_assert_runner totals after 9.9-d-2**:
72 passed, 234 failed, 286 skipped over 4 manifests.
Failure categories:
- 14 `compile: UnsupportedOp` — ARM64 emit gaps:
  load8x8_{s,u} / load16x4_{s,u} / load32x2_{s,u} (extend);
  load{8,16,32,64}_splat (splat-from-mem); load{8,16,32,64}_lane
  / store{8,16,32,64}_lane (lane-merge mem); load{32,64}_zero;
  select on v128 (simd_select.0).
- 1 `BadBlockType`, 1 `BadValType`, 1 `NotImplemented`
  — small-cluster surfaces, investigate per-case.
- 150 value-mismatch (`→ got`) — almost all in simd_const,
  likely f32x4/f64x2 NaN canonicalization or specific lane
  encoding differences vs spec hex tokens.

**Next — 9.9-d-3**: bundle the ARM64 v128 mem op family. Per
chunk-granularity rule "same dispatch helper consumer": all
new ops route through `v128MemPrologue` + a final encoder pair.
Reuse pattern from x86_64's §9.7-ax..bb cluster (which bundled
22 ops). Estimated 14 ops in one chunk:
- `load8x8_{s,u}` / `load16x4_{s,u}` / `load32x2_{s,u}` —
  load 8 bytes via `LDR D` then NEON SXTL/UXTL .8H / .4S / .2D.
- `load{8,16,32,64}_splat` — `LD1R.{8B/16B,4H/8H,2S/4S,1D/2D}`
  or `LDR + DUP` from staged GPR.
- `load{32,64}_zero` — `LDR S/D` (zero-extends upper lanes).
Then a separate small chunk for load/store_lane (8 ops, mem +
lane-imm) and select on v128 (1 op).

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
§9.9 in-flight (9.9-a..c + 9.9-d-1, 9.9-d-2 landed; 9.9-d-3
NEXT — ARM64 v128 mem op family bundle).
**Branch**: `zwasm-from-scratch`。
