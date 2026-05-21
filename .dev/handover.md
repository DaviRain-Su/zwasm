# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — §9.12-F + §9.12-I in progress

§9.12-F (debt active rows < 15) and §9.12-I (ADR canonical pass)
both open. Current state:

| Exit criterion                  | Latest fact                                                                |
|---------------------------------|----------------------------------------------------------------------------|
| §9.12-F: debt active rows < 15  | 23 (down from 24 last cycle; D-018 discharged this commit)                 |
| §9.12-I: ADR `Accepted` < 30    | strict 33 / loose 52 — structurally blocked on Phase 9 + §9.12 close       |
| `check_adr_history.sh --gate` 0 | 1 pending (template only) — ✓                                              |
| `check_lesson_citing.sh` 0      | 0 unfilled ✓                                                               |

**This commit (debt sweep)**:

- D-018 discharged. §9.12-H bench (`600bd7cf`) ran 26-fixture
  × 2-runtime hyperfine pass; RSS profile reflects page-
  allocation, not arena bloat. Per D-018's own discharge
  criterion ("no measurable pressure"), close. Long-running
  cross-module workload bench (Phase 11+) can re-open if
  specific pathology surfaces.
- D-155 removed from Discharged section (per "remove after
  one cycle" rule in debt.md header).
- §9.12-F sub-items re-walked, barriers hold (Last reviewed
  bumped to 2026-05-21):
  - D-022: blocked-by ADR-0028 M3-a-2 (trap event runtime
    write) + interp trap-location wiring. ADR-0028 status
    closed but M3-a-2 implementation not landed.
  - D-062: blocked-by arm64 v128 stack-overflow path (9th+
    v128 arg).
  - D-090: blocked-by lower.zig type-stack walker (~150
    LOC + ADR-grade decision); discharge trigger (non-i32
    select fixture in corpus) not fired.
  - D-094: blocked-by x86_64 multi-result indirect-result-
    buffer ABI; discharge trigger (real workload demanding
    >2 same-class results) not fired.
- D-055 (status `now`, mechanical): 95 expectEqualSlices
  sites + 5-line wire. Multi-cycle work; no progress this
  commit.
- D-081 (blocked-by ADR-0054 amendment OR ADR-0081 successor):
  ADR-0081 Accepted but doesn't dissolve barrier (per its
  Withdrawn-pair lesson). Holds.

**Next pickup**: § §9.12-F's < 15 exit needs ~8 more
discharges. Candidates requiring concrete code work:
D-055 (mechanical multi-cycle), D-090 (lower.zig type-stack
walker), D-094 (x86_64 indirect-result-buffer ABI), D-141
(per-file split ADRs + impl). Each is a substantial work
item; sequence by impact.

## Recent context

- §9.12-G closed (`4bd62842`); §9.12-H closed (`600bd7cf`).
- §9.12-I batch 1 (`1095d225`): 27 ADRs flipped.
- §9.12-I batch 2 (`5e2b1a6e`): 2 P7 meta ADRs flipped.
- §9.12-F debt sweep (this commit): D-018 discharged; 4 sub-
  items Last reviewed bumped.

## Active `now` debts

- **D-055** (mechanical, multi-cycle): emit_test_int has
  ~95 sites pending; barrier dissolved per row.

## Other queued work

1. **§9.12-F next discharge candidates** — D-141 (file-size
   per-file ADRs), D-090 / D-094 (deep ABI work), D-055
   (mechanical sites).
2. **§9.12-I revisit after Phase 9 + §9.12-F close**.

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK.
- §9.12-F: `[ ]` in ROADMAP — 23 active debts; exit < 15.
- §9.12-G: closed (`4bd62842`).
- §9.12-H: closed (`600bd7cf`).
- §9.12-I: 2 batches landed; structurally blocked on P9 + §9.12-F.

## Open questions / blockers

- なし for §9.12-F continued discharge.

## See

- [ROADMAP](./ROADMAP.md) §9.12-F + §9.12-I scope + exit
- [`debt.md`](./debt.md), [`lessons/INDEX.md`](./lessons/INDEX.md)
