# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — §9.12-F D-081 closed (ADR-0054 amendment)

§9.12-F (debt active rows < 15) and §9.12-I (ADR canonical) open.

| Exit criterion                  | Latest fact                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| §9.12-F: debt active rows < 15  | 19 (D-081 closed this commit; was 20)                                       |
| §9.12-I: ADR `Accepted` < 30    | strict 33 / loose 52 — blocked on Phase 9 close                             |

**This commit (D-081 close — ADR-0054 amendment)**:

ADR-0054 §"Naming convention" amended with a Revision history
entry adding a legacy-file grandfather clause. The strict
`<source>_test.zig` shape is forward-looking for new files;
the two legacy catalog test files predating the convention are
grandfathered:

- `src/engine/codegen/x86_64/emit_test_int.zig` (~1600 LOC)
- `src/engine/codegen/x86_64/emit_test_float.zig` (~1500 LOC)

Both test ops scattered across many per-op `op_*.zig` files
(per ADR-0074 absorbed the int/float emit content); no single
source file matches their name. The ADR amendment lists the
two grandfathered sites explicitly so future audits don't
re-flag them.

**§9.12-F phase-9-eligible cohort status** (per row text:
D-094 / D-090 / D-062 / D-141 / D-081 / D-055):
- D-090 closed (`2f54f753`)
- D-141 closed (`5081d053`)
- D-055 closed (`871c78e1`)
- D-081 closed (this commit, ADR-0054 amend)
- D-094 / D-062 — discharge trigger conditions not fired (no
  fixtures exercise the relevant ABI / arm64 9th+ v128 arg
  paths)

4 of 6 phase-9-eligible debts closed. Remaining D-094 / D-062
have trigger-not-fired barriers — would need fixtures to
demand the work. §9.12-F could plausibly be flipped [x] now
with the interpretation "phase-9-eligible cohort substantially
addressed; remaining 2 rows wait on future fixture triggers"
(would need §18 ADR for exit criterion re-framing).

**Next pickup**: §9.12-F exit re-framing OR continue with
remaining debt rows (all deferred to future phase per their
barrier text). Discussion-grade decision.

## Recent context

- §9.12-G closed (`4bd62842`); §9.12-H closed (`600bd7cf`).
- §9.12-I batches 1+2.
- §9.12-F discharges: D-018 / D-055 / D-090 / D-141 / D-081
  (`02397144` / `871c78e1` / `2f54f753` / `5081d053` / this).
- D-055 migration batches 1+2 + close.

## Active `now` debts

- なし.

## Other queued work

1. **§9.12-F exit re-framing** OR continue D-094 / D-062
   trigger-watch.
2. **§9.12-I revisit after Phase 9 close**.

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK.
- §9.12-F: 19 active rows; 4 of 6 phase-9-eligible debts closed.
- §9.12-G / §9.12-H / D-055 / D-090 / D-141 / D-081: closed.
- §9.12-I: 29 ADRs flipped; blocked on Phase 9 close.

## Open questions / blockers

- §9.12-F exit criterion (`< 15`) vs phase-9-eligible cohort
  (4/6 closed): re-framing decision deferred to user/audit.

## See

- [ROADMAP](./ROADMAP.md) §9.12-F + §9.12-I scope + exit
- [`debt.md`](./debt.md), [`lessons/INDEX.md`](./lessons/INDEX.md)
- ADR-0054 (Track B source-split + naming convention)
