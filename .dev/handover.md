# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10` — last code commit: `7945084f`
   (ADR-0081 Proposed — Phase 1 emit_setup.zig extraction, ~163
   LOC pure-function helpers). Awaiting impl cycle.
2. **User directive (2026-05-21)**: batch-session architectural
   mode.
3. **Live status**: `bash scripts/p9_completion_status.sh` —
   D-055 `Status: now`; D-081 blocked; ADR-0081 Phase 1 sized
   at ~163 LOC move (mechanical, single-cycle).

## Authorized next-session pickup (priority order — updated 2026-05-21)

1. **PRIMARY: ADR-0081 Phase 1 impl (emit_setup.zig
   extraction)**. ADR Proposed at `7945084f`. Mechanical:
   - **next cycle**: create
     `src/engine/codegen/x86_64/emit_setup.zig` with the four
     declarations (computeOutgoingMaxBytes lines 117-195,
     localDisp 1217-1237, LocalLayout 1238-1252,
     computeLocalLayout 1253-end). Update emit.zig: remove
     those four decls, add 5-line import + alias block + `pub
     const localDisp = setup.localDisp;` re-export for tests.
     Test gate: `cohort` (test-all). emit.zig 1300 → ~1140.
   - **after impl**: ADR-0081 Status: Proposed → Accepted on
     green gate. D-141 row's "emit.zig × 2 arches" slot closes
     for x86_64 side.
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
  closed; D-157 filed. 2026-05-21 resume: D-055 stays `Status:
  now` (mechanical work, unpaired from D-081 post-ADR-0080
  Withdraw); D-081 re-blocked pending ADR-0081 pivot decision.
  ADR-0080 Withdrawn same-day; lesson
  `emit-zig-survey-per-op-pattern-already-absorbed.md` captures
  the survey-time discipline gap.

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
