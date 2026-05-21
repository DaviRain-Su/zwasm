# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10` — last code commit is the
   barrier-dissolution flip cycle landing now (debt walk:
   D-055 + D-081 → `Status: now`; D-018 wording refresh).
2. **User directive (2026-05-21)**: batch-session / multi-cycle
   architectural mode authorized. Lift single-cycle-tractable
   self-restriction.
3. **Live status**: `bash scripts/p9_completion_status.sh` —
   `now` rows = 2 (D-055 + D-081, paired discharge in emit.zig
   int/float split session).

## Authorized next-session pickup (priority order — updated 2026-05-21)

1. **PRIMARY: ADR-0080 (emit.zig int/float source split) +
   discharge of D-055 + D-081**. Barriers dissolved this resume
   per Step 0.5 (prologue.zig helper landed at `ac8238bf` via
   D-052 close). Multi-cycle architectural chunk:
   - **cycle 1**: draft `.dev/decisions/0080_emit_zig_int_float_
     split.md` Proposed (follow ADR-0079 shape: Context naming
     the bloat axis, Decision proposing split into `emit_int.zig`
     / `emit_float.zig` / `emit.zig` driver, Alternatives noting
     source-family vs op-family trade-offs, file-layout proposal).
   - **cycle 2-3**: execute split — distribute helpers per ADR,
     `git mv emit_test_{int,float}.zig → emit_{int,float}_test
     .zig`, update `src/zwasm.zig` root imports, migrate ~95
     `expectEqualSlices` test sites to `body_start_offset()`-
     relative via prologue helper (paired D-055 work).
   - **cycle 4 (sentinel)**: wire `inst.encMovMemDisp32Imm32`
     call in emit.zig prologue (5-line patch); D-055 fully
     closed.
   Files touched: `src/engine/codegen/x86_64/{emit,emit_int,
   emit_float,emit_int_test,emit_float_test,prologue}.zig`,
   `src/zwasm.zig`.
2. **§9.12-F debt-cohort processing (continue)**. After D-055 /
   D-081 close, walk remaining 22 `blocked-by:` rows on each
   subsequent resume's Step 0.5 (already happening per
   discipline). Goal: debt < 15 by Phase 9 close. External-
   blocker rows (D-010, D-021, D-028, D-148) likely hold;
   structural rows (D-094, D-141) progress alongside.
3. **D-141 per-file ADRs + splits (parallel to #1)** —
   ADR-0079 shape for each. Priority by structural impact:
   - `src/validate/validator.zig` (1699 LOC) — next ADR-0081
   - `src/ir/dispatch_collector.zig` (1397 LOC)
   - `src/engine/codegen/{arm64,x86_64}/regalloc.zig`
   - `src/engine/codegen/{arm64,x86_64}/inst*.zig`
   - `src/engine/codegen/x86_64/op_simd_int_cmp_lane.zig`
     (2121 LOC — over hard cap)
4. **§9.12-G `src/api/instance.zig` split** (1424 LOC). Per-
   file ADR + extraction following ADR-0079.
5. **§9.12-H bench baseline** (Mac Wasm 2.0 + wasmtime × 26
   fixtures × hyperfine). Provides D-018 measurement that
   lets that row discharge.
6. **§9.12-I ADR/lesson curation closure**. Judgment-heavy.

## Active state (snapshot)

- **§9.12-A enforcement layer fully load-bearing**: 9 items OK
  per `p9_completion_status`; `gate_commit` strict --gate for
  libc + fallback; `pre-push` runs 4 audit gates; §7.9
  `feature_level_check.zig` comptime invariant landed
  (`2d6bd6ca`).
- **§9.12-E [x]** at `7b2e1b02`.
- **ADR-0078 fully load-bearing**: G.1.1 + G.1.2 + amendment;
  pre-push wired.
- **ADR-0079 fully closed** (runner.zig split).
- **§9.12-G partial**: 41 Wasm 3.0 stubs across 6 cohorts +
  dispatcher comptime-reject + CLI --invoke. Discrete-opcode
  stub coverage structurally complete. Remaining: api/instance
  split (#3 above) + c_api Instance tests (D-139 blocked).
- **§9.12-F**: 24 debt rows; D-149/153/154/156/102/103/105/155
  closed; D-157 newly filed. 2026-05-21 resume: D-055 + D-081
  barrier-dissolution flip to `Status: now` (paired discharge
  via ADR-0080 emit.zig int/float split, multi-cycle).

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
