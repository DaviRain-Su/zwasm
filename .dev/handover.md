# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.9 row — Phase 9 active.
3. `.dev/debt.md` — D-063 / D-065 + 11 `blocked-by:` rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: simd ops, ARM64 NEON, ADR-0041 §5).
5. `.dev/decisions/0041_simd_128_design.md` (SSE4.2 baseline).

## Current state — Phase 9 / §9.9 in-flight; **9.9-g NEXT — investigate D-063 (simd_const.386 call_indirect v128 Trap) OR scale the spec corpus toward §9.10 smoke benches**

9.9-f-8 (`<pending-sha>`): one-line validator fix — added 213
to the 94..211 binop list. The ARM64 emit handler `emitI64x2Mul`
(GPR-detour synthesis) + dispatch were pre-existing from
§9.5-c-vii-mul; the structural gap was validator-only.
Discharges D-064.

**Mac aarch64 simd_assert_runner totals after 9.9-f-8**:
**3549 PASS** (was 3366, +183) / **3 FAIL** (was 5, -2) /
1520 SKIP. 3-host gate green for the f-7 commit; OrbStack
green for f-8.

Residual 3 fails:
- 2× simd_const call_indirect v128 Trap (D-063, `now`).
- simd_const.388 BadValType (parse-side gap).

**Next — choose between**:
- **9.9-g-1** (discharge D-063): debug call_indirect v128
  marshal trap. Spike via `debug_jit_auto` skill: insert
  `BRK #0` after the bounds+sig check to localise whether
  trap is in the bounds/sig check path or the callee body
  itself. Direct `call $f` PASSES same module, isolating
  to call_indirect-specific work.
- **9.9-g-2** (scale corpus): add more spec fixtures to
  the manifest (e.g. `simd_int_arith2`, `simd_lane`,
  `simd_load_extend`) — push PASS count toward §9.10
  smoke-bench territory. Faster wall-clock; defers D-063.

Default: 9.9-g-1 (discharge `now` debt before scaling).

After §9.9: §9.10 (smoke benches + gap analysis), §9.11
(audit + SHA backfill), §9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-063** (simd_const.386 call_indirect v128 Trap) — `now`.
- **D-065** (arm64/inst_neon.zig 2029 LOC > 2000 cap) —
  blocked-by ADR for source-split (mirror of D-057).
- **D-055** (x86_64 prologue inject) — blocked-by D-052.
- **D-057** (x86_64 op_simd.zig 4442 LOC hard-cap) —
  blocked-by ADR for source-split landing.
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
§9.9 in-flight (9.9-a..c + 9.9-d-1..7 + 9.9-e-1..2 +
9.9-f-1..8 landed; 9.9-g NEXT).
**Branch**: `zwasm-from-scratch`。
