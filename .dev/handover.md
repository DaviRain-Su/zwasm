# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10` — last code commit: `99dcc932`
   (ADR-0082 Proposed — dispatch_collector_ops.zig extraction,
   ~900 LOC registry move). Impl cycle next.
2. **User directive (2026-05-21)**: batch-session architectural
   mode.
3. **Live status**: `bash scripts/p9_completion_status.sh` —
   D-055 `Status: now`; D-081 blocked; ADR-0082 awaits impl.

## Authorized next-session pickup (priority order — updated 2026-05-21)

1. **PRIMARY: ADR-0082 impl (dispatch_collector_ops.zig
   extraction)**. ADR Proposed at `99dcc932`. Carve cycle:
   - Create `src/ir/dispatch_collector_ops.zig` with 419 op
     imports + `collected_ops` tuple (lines 151–1055 of
     dispatch_collector.zig). Add std/zir/build_options
     imports needed by the imports themselves.
   - Update `dispatch_collector.zig`: remove lines 151–1055,
     add `const ops_registry = @import("dispatch_collector_ops.zig");
     pub const collected_ops = ops_registry.collected_ops;`.
   - Cohort gate (test-all). feature_level_check.zig uses
     `collector.collected_ops` — re-export preserves it.
   - dispatch_collector.zig 1397 → ~500; new ops file ~900.
2. **Next D-141 candidate** (after #1 lands):
   - `src/validate/validator.zig` (1699 LOC) — ADR-0083
     candidate.
   - `src/engine/codegen/x86_64/op_simd_int_cmp_lane.zig`
     (2121 LOC — over hard cap).
3. **D-055 discharge (independent)**. Test-array migration
   to `setup.localDisp()` + sentinel wire-up. Multi-cycle.
4. **§9.12-F debt-cohort walk** continues per Step 0.5.
2. **D-081 decision deferred to ADR-0081 cycle**: re-blocked
   pending ADR-0054 amendment OR alternative path. Not urgent
   for §9.12-F debt target (D-081's barrier wording is now
   accurate; row stays `blocked-by:` until structural path
   chosen).
3. **§9.12-F debt-cohort processing (continue)**. After D-055
   close, walk remaining 23 `blocked-by:` rows on each
   subsequent resume's Step 0.5. Goal: debt < 15 by Phase 9
   close. External-blocker rows (D-010, D-021, D-028, D-148)
   likely hold; structural rows (D-094, D-141) progress
   alongside.
4. **D-141 per-file ADRs + splits** — pickup remaining
   files per ADR-0079 shape: validator.zig (1699) /
   dispatch_collector (1397) / regalloc / inst /
   op_simd_int_cmp_lane (2121 over hard cap).
5. **§9.12-G `src/api/instance.zig` split** (1424 LOC).
6. **§9.12-H bench baseline** (Mac Wasm 2.0 + wasmtime ×
   hyperfine) — also discharges D-018.
7. **§9.12-I ADR/lesson curation closure**. Judgment-heavy.

## Active state (snapshot)

- **§9.12-A enforcement**: 9 items OK; `gate_commit` strict
  --gate for libc + fallback; `pre-push` 4 audit gates;
  §7.9 `feature_level_check.zig` (`2d6bd6ca`).
- **§9.12-E [x]** at `7b2e1b02`.
- **ADR-0078 fully load-bearing**: G.1.1 + G.1.2 + amendment;
  pre-push wired.
- **ADR-0079 fully closed** (runner.zig split).
- **§9.12-G partial**: 41 Wasm 3.0 stubs across 6 cohorts +
  dispatcher comptime-reject + CLI --invoke. Discrete-opcode
  stub coverage structurally complete. Remaining: api/instance
  split (#3 above) + c_api Instance tests (D-139 blocked).
- **§9.12-F**: 24 debt rows; D-149/153/154/156/102/103/105/155
  closed; D-157 filed. 2026-05-21: ADR-0081 Accepted (`b8d91990`);
  D-141's x86_64 emit.zig slot closed. D-055 `Status: now` (test
  migration unpaired from D-081). D-081 still blocked (ADR-0054
  amendment path). ADR-0080 Withdrawn precedent + lesson
  `emit-zig-survey-per-op-pattern-already-absorbed.md` shapes
  future ADR drafts.

## Operational note for the batch-session loop

`/continue` resume Steps 0-7 still apply per cycle, but: granularity
is `architectural` (per LOOP.md), not `emit`. Spike-first allowed
for design questions (e.g. validator split boundaries). Up to 3
cycles without measurable progress before re-evaluating chunk
shape. Cite ADR-0079 as the shape precedent in commit bodies.

## Open questions / blockers

- なし。autonomous batch-session resumed at user direction.

## See

- [ROADMAP](./ROADMAP.md) §9.12 — F / G / H / I open.
- [`debt.md`](./debt.md) — 24 active rows (walk all on resume).
- [`decisions/0079_runner_zig_split.md`](./decisions/0079_runner_zig_split.md)
  — per-file ADR + execution shape precedent.
- [`lessons/INDEX.md`](./lessons/INDEX.md).
