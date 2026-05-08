# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — D-054 + D-055 `blocked-by:` chain; 9 other rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: hoist-vreg-semantic, regalloc-pool-size-mismatch, w54-class).
5. `.dev/decisions/0031_zir_hoist_pass.md` (ADR-0031 hoist design + cap=4 amend).
6. `.dev/decisions/0033_pass_trace_extension.md` + `0034_jit_execution_sentinel.md`
   (8a.1 + 8a.2 observability infra; the read-side for 8a.5).

## Current state — Phase 8 / §9.8a / 8a.5 (D-053 + D-054 cap-removal investigation)

§9.8a / 8a.1-8a.4 closed. The four foundation rows landed
across this session arc. Now the substantive 8a.5 row begins:
the cap-removal investigation that uses 8a.1 (pass-trace) +
8a.2 (sentinel) + 8a.3 (bench-delta) + 8a.4 (ZWASM_DIAG drain)
to localise which silent `UnsupportedOp` in
`arm64/{op_call,op_control,gpr}.zig` fires under post-hoist
IR with > 4 synthetic locals.

直近 commits (latest at top):

- (this commit) chore(p8): mark §9.8a / 8a.4 [x]; retarget at
  8a.5 cap-removal investigation.
- `9785ab8` feat(p8): §9.8a / 8a.4 — ZWASM_DIAG runtime opt-in.
- `d0a364b` feat(p8): §9.8a / 8a.3 — bench-delta-per-commit.
- `308ca97` feat(p8): §9.8a / 8a.2-d — realworld_run_jit
  cross-process sentinel surface (closes 8a.2 minus D-055).

3-host gate at `9785ab8`: Mac green, OrbStack 1 known D-054
FAIL only, windowsmini green.

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; 8a.1-8a.4 [x];
**§9.8a / 8a.5 NEXT**. Phase 8 残 rows = 8a.5 + 8a.6 +
8b.1-8b.6.

## Active task — §9.8a / 8a.5: D-053 + D-054 cap-removal investigation **NEXT**

Per ROADMAP row text:
> Using 8a.1 + 8a.2, identify which silent UnsupportedOp source
> in arm64 `op_call.zig` / `op_control.zig` / `gpr.zig` fires
> under post-hoist IR with > 4 synthetic locals. Either fix the
> affected emit path (preferred) or refine the cap into a
> precise filter (acceptable). On success: remove
> `max_hoists_per_func = 4` from `src/ir/hoist/pass.zig`.
> Verifies via `realworld_run_jit` baseline maintained AND
> increased hoist application count (per 8a.1 pass-trace
> counters). Discharges D-053.

8a.5 also discharges **D-054** (OrbStack as-loop-broke) once
the localised regression is fixed AND **D-055** (x86_64
sentinel) once the same path validates on x86_64.

Suggested chunk plan:

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8a.5-a | Build with `-Dtrace-ringbuffer=true`; reproduce cap-removed regression locally on Mac aarch64; capture pass-trace + emit-stage logs | **NEXT** |
| 8a.5-b | Bisect to identifying single fixture + pass+func combo where post-hoist IR triggers UnsupportedOp; small reproducer fixture | [ ]      |
| 8a.5-c | Either fix emit path OR refine cap into structurally-correct filter | [ ]      |
| 8a.5-d | Remove `max_hoists_per_func` cap from `src/ir/hoist/pass.zig`; verify baseline ≥ 15/55 RUN-PASS + hoist count increased | [ ]      |
| 8a.5-e | 3-host gate; close D-053 + D-054 + D-055 contingent; close 8a.5 [x] | [ ]      |

After 8a.5 closes: 8a.6 (8a boundary audit). Then §9.8b begins.

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-055** (`blocked-by: D-052 + emit_test_*.zig migration`) —
  x86_64 prologue inject deferred.
- **D-054** (`blocked-by: 8a.5 + D-055`) — OrbStack-only as-
  loop-broke regression.
- 9 `blocked-by:` rows — D-007 / D-010 / D-016 / D-018 / D-020
  / D-021 / D-022 / D-026 / D-028 / D-052; barriers all hold
  this resume.

D-053 promoted to ROADMAP row §9.8a / 8a.5 per ADR-0032.

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
