# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).
> Framing discipline per
> [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Cold-start procedure — §9.13-0 cohort autonomous start

Open work: §9.13-0 (Cat IV windowsmini reconcile) + §9.12-F /
§9.12-I cleanup. §9.12-E ★ (Wasm 2.0 100%, 4 testsuites green)
DONE. The autonomous loop drives §9.13-0 forward in `emit` /
`infrastructure` chunks; the per-cycle commit pair lands work
even if many cycles are needed.

| Exit criterion                  | Latest fact                                                       |
|---------------------------------|-------------------------------------------------------------------|
| §9.13-0 windowsmini full green  | not yet; Cat IV cohort 4 debts open (D-022, D-028, D-084, D-136)  |
| §9.12-F: debt active rows < 15  | 19 (cleanup; criterion likely needs §18 amendment — file ADR)     |
| §9.12-I: ADR `Accepted` < 30    | strict 33 / loose 53 (blocked on Phase 9 close)                   |

## Active task — §9.13-0 chunk 1

**First chunk** (autonomous, `emit` or `infrastructure`):

`§9.13-0-a — inventory the 4 Cat IV debts on windowsmini`. Run
`bash scripts/run_remote_windows.sh test-all > /tmp/win.log 2>&1`
foreground (Bash timeout ≥ 600000 ms) to capture the actual
failure landscape. Read the log tail; produce
`private/notes/p9-9.13-0-survey.md` enumerating which debts
each FAIL maps to. This is `survey`-typed; commit the survey
note (gitignored) reference in handover and proceed to chunk 2.

**Chunk 2 candidate** (post-survey): pick the highest-leverage
debt and land its fix as a focused `emit` chunk. D-084 (Win64
v128 marshal) likely smallest; D-136 (SEH bridge) likely
largest. Order TBD by survey evidence.

## §9.12-F exit re-framing (parallel autonomous track)

The §9.12-F exit criterion ("debt active rows < 15") is a §9
phase-row exit. Re-framing it touches ROADMAP §9 → requires
ADR per §18.2. **This is the only `user-judgment` flagged in
handover** (per `handover_framing.md`); the autonomous loop
can draft the ADR (`.dev/decisions/NNNN_phase9_debt_exit_
reframe.md`) with `Status: Proposed` and surface for user
review at ADR-flip time.

## Recent context

- §9.12-G closed (`4bd62842`); §9.12-H closed (`600bd7cf`).
- §9.12-I batches 1+2 + ADR-0034 flip.
- §9.12-F discharges: D-018 / D-055 / D-090 / D-141 / D-081.
- D-055 migration batches 1+2 + close (`871c78e1`).
- Plateau-period cleanups + `2026-05-21-debt-stale-framing-pattern.md`.

## Active `now` debts

- なし (handle as part of §9.13-0 chunks).

## §9.13-0 Cat IV cohort (the autonomous target)

- **D-084** Win64 v128 marshal residual.
- **D-136** Win64 SEH bridge for `assert_trap` recovery
  (C/asm shim alongside Zig).
- **D-028** windowsmini SSH test-runner IPC flake.
- **D-022** Win64 cross-platform residual (paired with above).

## Open questions / blockers

- §9.12-F exit re-framing — **ADR-drafting is autonomous**;
  ADR-flip review needs user. Not a stop on chunk progress.

## See

- [ROADMAP](./ROADMAP.md) §9.13-0 + §9.12-F + §9.12-I
- [`debt.md`](./debt.md), [`lessons/INDEX.md`](./lessons/INDEX.md)
- New rule: [`handover_framing.md`](../.claude/rules/handover_framing.md)
