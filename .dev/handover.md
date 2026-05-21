# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — §9.12-I in progress

§9.12-I (ADR + lesson + private/ closure). Exit criteria:

| Exit criterion                  | Latest fact                                                                              |
|---------------------------------|------------------------------------------------------------------------------------------|
| `check_adr_history.sh --gate` 0 | 1 pending (template only) — gate exits 0 ✓                                               |
| `check_lesson_citing.sh` 0      | 0 unfilled ✓                                                                             |
| ADR `Accepted` count < 30       | strict `^- **Status**: Accepted$` count = 35; loose (incl. annotated) = 54 — still open  |

**This commit (ADR canonical pass batch 1)**: 27 ADRs flipped
`Accepted` → `Closed (Phase N DONE)` for Phase 1/2/3/4/6/7/8
cohort whose `**Tags**` line names only DONE phases. Frontmatter
`status:` + body `**Status**:` both updated; no Revision history
row added (this is a routine batch closure, not an amendment).

Targets flipped (by ADR num + closing phase):

- Phase 1: 0002
- Phase 2: 0003
- Phase 3: 0004
- Phase 4: 0005
- Phase 6: 0008, 0012, 0013, 0015, 0016
- Phase 7: 0014, 0017, 0018, 0019, 0021, 0023, 0024, 0026, 0029
- Phase 8: 0030, 0031, 0032, 0033, 0036, 0037, 0038, 0039, 0040

**Deliberately NOT flipped (need per-ADR review next cycle)**:

- Annotated `Accepted (partial — ...)` / `Accepted (scope
  downgraded ...)`: 0025, 0034, 0035, and ~12 others. Manual
  review per ADR (the annotation carries context that auto-flip
  would lose).
- Meta-tagged (no phase tag in `**Tags**` line): 0009, 0020,
  0022, 0027, 0028, 0049, 0050, 0052, 0053, 0060, 0062, 0063,
  0064, 0067, 0074, 0076, 0077, 0081–0093, 0098, 0099, 0100,
  0101 (≈34 ADRs). Most are file-layout reform (zone-1 / zone-2
  cap discipline) tied to §9.12 — keep `Accepted` until §9.12-I
  closes.
- Phase-9 cohort (17 ADRs): 0041, 0054, 0055, 0056, 0057, 0058,
  0059, 0061, 0065, 0066, 0068, 0070, 0071, 0072, 0073, 0075,
  0094. Phase 9 still IN-PROGRESS; stay `Accepted`.

**Next pickup**: ADR canonical pass batch 2 — review the
annotated `Accepted (partial ...)` cohort. Each one needs an
individual judgment (still load-bearing? converted to `Closed
(Phase X DONE; <deferral note>)`?). After batch 2: skip-ADR
Status wording cleanup (skip_cross_module_register /
skip_cross_module_action) and Lesson promotion scan.

## Recent context

- §9.12-G closed (`4bd62842`); §9.12-H closed (`600bd7cf`).
- File-size reform (cycles C1..C6): ADR-0099/0100/0101 etc.

## Active `now` debts

- **D-055** (mechanical, multi-cycle): emit_test_int has 27 sites
  pending.

## Other queued work

1. **§9.12-I ADR canonical pass batch 2** — annotated cohort.
2. **D-055 continuation**.
3. **Phase 10 ZirOp slot policy ADR** — gates memory64 /
   relaxed-simd file-level placeholders.

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK.
- §9.12-F: `[ ]` in ROADMAP. D-141 portion absorbed by
  file-size reform (ADR-0099/0100/0101). Remaining sub-items
  per row text: D-094 / D-090 / D-062 / D-081 / D-055.
- §9.12-G: closed (`4bd62842`).
- §9.12-H: closed (`600bd7cf`).
- §9.12-I: in progress (batch 1 this commit + batch 2 to come).

## Open questions / blockers

- なし for §9.12-I canonical pass batch 2.

## See

- [ROADMAP](./ROADMAP.md) §9.12-I scope + exit
- [`scripts/check_adr_history.sh`](../scripts/check_adr_history.sh)
- [`scripts/check_lesson_citing.sh`](../scripts/check_lesson_citing.sh)
- [`debt.md`](./debt.md), [`lessons/INDEX.md`](./lessons/INDEX.md)
