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

## Current state — Phase 9 / §9.9 in-flight; **9.9-f-4 NEXT — call_indirect Trap when invoking v128-arg target (likely sig-typeidx comparison gap or call_indirect-specific marshal path)**

9.9-f-3 (`80b2f1c5`): three structural ARM64 fixes — (1)
`emitEndIntra` v128 merge MOV (per-slot `alloc.shapeTag`
dispatch; replaces 32-bit scalar ORR W with 128-bit
`encMovV16B` for v128 slots); (2) `marshalCallArgs` v128
caller-side marshal (V0..V7 + 16-byte-aligned stack overflow
per AAPCS64 §6.4.2 stage C.4); (3) `captureCallResult` v128
(callee returns v128 in V0). Unblocks simd_const.386 end-
to-end.

**Mac aarch64 simd_assert_runner totals after 9.9-f-3**:
**412 PASS** (was 394, +18) / **4 FAIL** (was 3, +1) /
305 SKIP. The new FAIL is two `as-call_indirect-param()` /
`-param2()` Traps — call_indirect with v128 arg compiles
but traps at runtime. Tests: 1552/1564 Mac, 1536/1564
OrbStack.

Residual 4 fails:
- simd_const: as-call_indirect-param() Trap (NEW)
- simd_const: as-call_indirect-param2() Trap (NEW)
- simd_const.388 BadValType — parse-side gap
- simd_const.389 NotImplemented — separate

**Next — 9.9-f-4**: investigate the call_indirect Trap. The
JIT body emits the v128 marshal (no compile-time error) but
runtime traps. Likely the call_indirect type-check (compares
caller's expected typeidx vs callee's published typeidx)
mismatches when v128 is in the sig — or the table-entry
typeidx wasn't populated correctly by setupRuntime for
v128-bearing types. Spike via `debug_jit_auto` skill recipes;
likely a sig-comparison fix in op_call.zig's emitCallIndirect
or a setupRuntime gap.

After §9.9: §9.10 (smoke benches + gap analysis), §9.11
(audit + SHA backfill), §9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-055** (x86_64 prologue inject) — blocked-by D-052 prologue
  extract.
- **D-057** (op_simd.zig hard-cap, now ~4442 LOC) — blocked-by
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
§9.9 in-flight (9.9-a..c + 9.9-d-1..7 + 9.9-e-1..2 + 9.9-f-1..3
landed; 9.9-f-4 NEXT — call_indirect v128 Trap investigation).
**Branch**: `zwasm-from-scratch`。
