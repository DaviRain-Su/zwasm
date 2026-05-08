# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — D-054 + **D-055** `blocked-by:` chain; 9 other rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/decisions/0034_jit_execution_sentinel.md` (8a.2 design landed) +
   `0033_pass_trace_extension.md` (8a.1 design landed).
6. `.dev/decisions/0021_arm64_prologue_split.md` (helper pattern; reference for D-055 x86_64 extract).

## Current state — Phase 8 / §9.8a / 8a.2-d (realworld_run_jit integration)

§9.8a / 8a.2-a/b/c-i landed: ADR-0034 design + JitRuntime
field + ARM64 prologue inject + x86_64 encoder helper.
8a.2-c-ii (x86_64 wire-up) deferred to D-055 because the
existing x86_64 emit test landscape (95 `expectEqualSlices`
sites) requires `body_start_offset()`-helper migration before
the +7-byte prologue change can land without 50+ test-array
re-writes.

直近 commits (latest at top):

- (this commit) chore(p8): mark 8a.2-c-i [x] + D-055 deferral.
- `c5aaa50` feat(p8): §9.8a / 8a.2-c-i — x86_64 sentinel
  encoder + D-055 deferral.
- `d6e29ac` feat(p8): §9.8a / 8a.2-b — JitRuntime.jit_executed
  _flag + ARM64 prologue inject per ADR-0034.
- `5a6e42d` docs(p8): §9.8a / 8a.2-a — ADR-0034 design framing.

3-host gate at `e8e4d8c`: Mac green; OrbStack 1 known D-054
FAIL; windowsmini green. Sentinel currently ARM64-only —
`jit_executed_flag` flips on Mac aarch64; x86_64 hosts
report 0 until D-055 lands.

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; 8a.1 [x]; **§9.8a /
8a.2-d NEXT** (with 8a.2-c-ii blocked-by D-055). Phase 8 残
rows = 8a.2-d/e + 8a.3-8a.6 + 8b.1-8b.6.

## Active task — §9.8a / 8a.2-d: realworld_run_jit cross-process sentinel surface **NEXT**

Per ADR-0034: the realworld_run_jit fork-child writes a marker
line to stderr before exit:

```
[jit-exec-flag] 1
```

…or `0` if the JIT body never invoked. Parent's
`runFixtureWithTimeout` captures stderr (already collected
for trap diagnosis) and greps for the marker; the resulting
bool feeds new `RUN-JIT-VERIFIED` / `RUN-JIT-COMPILE-ONLY-PATH`
classifications in the runner's tally.

On Mac aarch64: marker reflects ARM64 sentinel — works as
designed. On OrbStack/windowsmini (x86_64): marker stays 0
until D-055 lands; runner reports `RUN-JIT-COMPILE-ONLY-PATH`
for all x86_64 fixtures despite actual JIT execution. This
asymmetry is **intentional and documented** — it's the cost
of the D-055 deferral.

Suggested chunk plan:

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8a.2-a | ADR `0034_jit_execution_sentinel.md` design framing      | [x] (`5a6e42d`) |
| 8a.2-b | JitRuntime field + ARM64 prologue inject + unit test     | [x] (`d6e29ac`) |
| 8a.2-c-i | x86_64 sentinel encoder helper + emit.zig deferral comment | [x] (`c5aaa50`) |
| 8a.2-c-ii | x86_64 prologue inject (wire-up) — **D-055 deferred** | [ ] (D-055) |
| 8a.2-d | realworld_run_jit child marker print + parent stderr grep + classification | **NEXT** |
| 8a.2-e | 3-host gate; close 8a.2 [x] (with 8a.2-c-ii note in close text) | [ ]      |

After 8a.2 closes: 8a.3 (bench-delta-per-commit), 8a.4
(`ZWASM_DIAG` env var), 8a.5 (D-053 + D-054 cap-removal
investigation), 8a.6 (8a boundary audit).

Then §9.8b begins: 8b.1 (Coalescer, bench-delta required) →
8b.2 (Regalloc upgrade) → 8b.3 (AOT skeleton) → 8b.4 (≥10%
aggregate) → 8b.5 (boundary audit) → 8b.6 (open §9.9).

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-055** (`blocked-by: D-052 + emit_test_*.zig migration`) —
  x86_64 prologue inject deferred; ARM64-only sentinel until
  test-helper migration enables low-friction prologue size
  change.
- **D-054** (`blocked-by: 8a.5 + D-055`) — OrbStack-only as-
  loop-broke regression; D-055 added to chain because cross-
  host differential (Linux x86_64 vs windowsmini x86_64) needs
  x86_64 sentinel.
- 9 `blocked-by:` rows — D-007 / D-010 / D-016 / D-018 / D-020
  / D-021 / D-022 / D-026 / D-028 / D-052; barriers all hold
  this resume.

D-053 promoted to ROADMAP row §9.8a / 8a.5 per ADR-0032.

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
