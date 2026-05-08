# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — D-054 + D-055 `blocked-by:` chain; 9 other rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/decisions/0034_jit_execution_sentinel.md` (8a.2 design + Revision history) +
   `0033_pass_trace_extension.md` (8a.1 design).
6. `.dev/decisions/0032_phase8_foundation_first_reorg.md` (Phase 8 sequencing).

## Current state — Phase 8 / §9.8a / 8a.3 (bench-delta-per-commit)

§9.8a / 8a.1 + 8a.2 closed. Two-channel diagnostic surface
landed (compile-pass record + JIT-execution sentinel). 8a.2-c-ii
(x86_64 sentinel wire-up) deferred via D-055; ARM64 fully
operational on Mac aarch64.

直近 commits (latest at top):

- (this commit) chore(p8): mark §9.8a / 8a.2 [x]; retarget at
  8a.3 bench-delta-per-commit.
- `308ca97` feat(p8): §9.8a / 8a.2-d — realworld_run_jit cross-
  process sentinel surface (closes 8a.2 minus D-055).
- `c5aaa50` feat(p8): §9.8a / 8a.2-c-i — x86_64 sentinel
  encoder + D-055 deferral.
- `d6e29ac` feat(p8): §9.8a / 8a.2-b — JitRuntime.jit_executed
  _flag + ARM64 prologue inject.

3-host gate at `c346666` (8a.2-d): Mac green; OrbStack 1
known D-054 FAIL only; windowsmini green (D-028 flake on
first run, retry green per the documented retry-once
discipline).

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; 8a.1 [x]; 8a.2 [x];
**§9.8a / 8a.3 NEXT**. Phase 8 残 rows = 8a.3-8a.6 (foundation)
+ 8b.1-8b.6 (optimisation).

## Active task — §9.8a / 8a.3: bench-delta-per-commit infra **NEXT**

Per ROADMAP §9.8a row text:
> `scripts/run_bench.sh --diff <ref>` produces a before/after
> fixture-by-fixture table (median_ms delta, percent change,
> regression highlight). `scripts/record_bench_delta.sh` formats
> it as a markdown block suitable for commit-message inclusion.
> Used by the new /continue skill bench-discipline trigger
> (8b tasks); also runnable manually for any ad-hoc verification.

This unlocks Step 5b of the per-task TDD loop (bench-delta
sub-step) which currently has all 3 trigger conditions
half-met: 8a.1 + 8a.2 [x]; 8a.3 [ ] is the gate.

Suggested chunk plan:

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8a.3-a | Survey existing `scripts/run_bench.sh` shape + bench/results/history.yaml structure | **NEXT** |
| 8a.3-b | Add `--diff <ref>` mode to run_bench.sh: produces fixture-by-fixture table comparing two SHAs from history.yaml | [ ]      |
| 8a.3-c | Add `scripts/record_bench_delta.sh`: formats output as markdown for commit-message inclusion | [ ]      |
| 8a.3-d | Smoke-test on Mac local with HEAD~5..HEAD; assert table renders + regression highlight fires | [ ]      |
| 8a.3-e | 3-host gate (mostly Mac-only; bench infra is host-local); close 8a.3 [x] | [ ]      |

After 8a.3 closes: 8a.4 (`ZWASM_DIAG` env var), 8a.5 (D-053 +
D-054 cap-removal investigation), 8a.6 (8a boundary audit).

Then §9.8b begins: 8b.1 (Coalescer, bench-delta required) →
8b.2 (Regalloc upgrade) → 8b.3 (AOT skeleton) → 8b.4 (≥10%
aggregate) → 8b.5 (boundary audit) → 8b.6 (open §9.9).

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-055** (`blocked-by: D-052 + emit_test_*.zig migration`) —
  x86_64 prologue inject deferred.
- **D-054** (`blocked-by: 8a.5 + D-055`) — OrbStack-only as-
  loop-broke regression.
- 9 `blocked-by:` rows — D-007 / D-010 / D-016 / D-018 / D-020
  / D-021 / D-022 / D-026 / D-028 / D-052; barriers all hold
  this resume. **D-028 flake fired this cycle** (windowsmini
  IPC-timeout); retry-once discipline confirmed flake (1109/1135
  + spec_assert 212/0/20 before flake on first run; full green
  on retry). Sample size 3/30 commits ≈ 10%; D-028's prior
  baseline was 2/30 ≈ 6%.

D-053 promoted to ROADMAP row §9.8a / 8a.5 per ADR-0032.

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
