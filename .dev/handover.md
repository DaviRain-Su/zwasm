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

## Current state — Phase 9 / §9.9 in-flight (9.9-a..b landed); **9.9-c populate manifest + JIT execution NEXT**

9.9-b: v128 return marshal per ADR-0046 (commit `aced46e5`).
Both backends — x86_64 MOVAPS XMM0, src_x; ARM64 MOV V0.16B,
Vn.16B. Uses resolveXmm/resolveFp (no spill staging) to surface
UnsupportedOp on spilled v128 explicitly (xmmLoadSpilled would
silently truncate to 64 bits). Updated v128-result rejection
test to expect success. v128 PARAM marshal split off per ADR-
0046. 3-host green.

**Next — 9.9-c** (renumbered from prior 9.9-b): populate
manifest with lightweight starter set per ADR-0045 + extend
runner with JIT execution. Now unblocked by 9.9-b's v128
return support.
- Extend `scripts/regen_spec_simd_assert.sh` with wast2json
  invocation pattern from `regen_spec_1_0_assert.sh` (lines
  60+); adapt Python distillation for v128 hex tokens.
- Initial NAMES: simd_address, simd_align, simd_const,
  simd_select (lightweight, total ~150 assertions).
- Extend `simd_assert_runner.zig` with manifest parsing,
  v128 hex token handling, JIT execution + assert_return
  comparison. New entry helper `callV128NoArgs` returning
  `[16]u8` (mirrors callI32NoArgs shape).
- Initial baseline: capture fail/skip count; commit + push.

Subsequent §9.9 chunks per ADR-0045:
- 9.9-d: iterate to fail=skip=0 on lightweight set.
- 9.9-e: v128 PARAM marshal per ADR-0046 (unblocks multi-arg
  spec assertions).
- 9.9-f: scale to FP arith + compares (heavy 9k+ files).
- 9.9-g: aggregate `test-spec-simd` into `test-all`; flip §9.9 [x].

After §9.9: §9.10 (smoke benches + gap analysis), §9.11
(audit + SHA backfill), §9.12 (open Phase 10).

Subsequent: §9.9 (simd.wast wired in, fail=skip=0), §9.10
(smoke benches + gap analysis), §9.11 (audit + SHA backfill),
§9.12 (open Phase 10).

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
§9.9 in-flight (9.9-a..b landed; ADR-0045 + ADR-0046; 9.9-c
NEXT populate manifest + JIT execution wiring).
**Branch**: `zwasm-from-scratch`。
