# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — FILE-SIZE DISCIPLINE REFORM IN PROGRESS

**Next-session pickup is the reform, NOT continued D-141 sweep.**

1. **Read `private/file-size-reform/README.md`** first IF AVAILABLE
   (gitignored; survives session continuity but not fresh-clone).
   If absent, the full 8-cycle plan is also in this handover.md.
2. Then `private/file-size-reform/07-execution-plan.md` for the
   8-cycle execution plan (or summary below if private/ absent).
3. Execute Cycle 1: land ADR-0099 (file-size discipline reframe)
   + .claude/rules/file_size_smell.md + scripts/check_split_smell.sh
   + amend lesson `2026-05-21-pure-data-extraction-via-reexport.md`.
4. Continue through Cycles 2-6 in order (Cycles 7-8 optional).
5. **DO NOT** start any new D-141 file-size extraction work
   until the reform lands. The discipline has changed.
6. **Path B vs Path A for sections (Cycle 5)**: Plan recommends
   Path B (extract init_expr.zig as deep utility; sub-steps
   5a/5b/5c). Path A (straight rollback + FILE-SIZE-EXEMPT marker
   on sections.zig) is acceptable interim. Decision at Cycle 5
   entry.

## Background

Post-D-141 retrospective surfaced that 3 of 15 D-141 sweep
extractions (ADR-0095, 0096, 0097) don't satisfy proper
architectural standards. Root cause: soft cap WARN was treated
as a forcing function rather than a smell detector (ADR-0063's
original intent drifted). The autonomous loop generated
shallow modules with helper-circular imports to satisfy the
metric.

The reform:
- Lands ADR-0099 (formal 4+4 conditions; EXEMPT marker becomes
  the default when no valid extraction exists)
- Lands ADR-0100 (rollback ADR-0097; supersede 0095/0096)
- Lands ADR-0101 (init_expr.zig — the proper deep utility
  redesign that 0095/0096 should have been)
- Adds .claude/rules/file_size_smell.md + scripts/check_split_smell.sh

## Active `now` debts

- **D-055** (mechanical, multi-cycle, partial): cumulative 30
  tests migrated. emit_test_float ~99% done. emit_test_int has
  27 sites pending. **Defer until file-size reform lands.**

## Other queued work (post-reform)

1. **§9.12-G `api/instance.zig` redesign** — c_api lifecycle
   redesign. Per ADR-0099 §D2, evaluate P3 conditions before
   extraction.
2. **§9.12-H bench baseline** — Mac Wasm 2.0 + wasmtime
   comparison.
3. **§9.12-I ADR/lesson curation closure** — Phase 9 close
   discipline.
4. **D-055 continuation** (after reform).
5. **Remaining D-141 WARN files** — per ADR-0099 §D2, most
   will resolve to FILE-SIZE-EXEMPT marker (not extraction).

## Active state (snapshot)

- **§9.12-A enforcement**: 10 items OK. Pending: add
  check_split_smell.sh per Cycle 2 of reform plan.
- **§9.12-F (D-141 sweep)**: 15 ADRs Accepted. Retrospective
  identified 3 for rollback/supersede via reform. Net after
  reform: 12 valid + 1 redesigned (init_expr) + retired 3.
- **§9.12-G/H/I**: open.
- Reform working dir: `private/file-size-reform/` (gitignored).

## Pattern menu (post-reform reference)

| Pattern | When applicable | Examples (validated) |
|---|---|---|
| Pure-data re-export (P2) | One block > 40% LOC, no methods, no state | ADR-0082, 0086, 0087, 0088, 0090 |
| Spec-defined sub-language (P1, ≥300 LOC) | Wasm proposal / ISA class | ADR-0083, 0089 |
| Pure top-level helper (P3 weak) | 3+ standalone helpers, no callers | ADR-0079, 0081, 0085 |
| Cross-file struct method (P1+N2-managed) | Struct-method-heavy file, paired with SIBLING-PUB | ADR-0083, 0089, 0098 |
| Per-caller migration (P3 strong) | N independent symbols, 100+ caller sites | ADR-0084 |
| Deep utility (P3) | Standalone module consumed by 2+ external | ADR-0091, 0092, 0093, ADR-0101 (planned) |
| **FILE-SIZE-EXEMPT** (no valid extraction) | Soft cap WARN but no smell present | entry.zig, op_simd_int_cmp_lane.zig |

## Operational note

The 2026-05-21 batch session demonstrated that the autonomous
loop will pursue metric-zeroing absent explicit guardrails.
ADR-0099 + check_split_smell.sh are the structural fix.

## Open questions / blockers

- なし。Reform plan complete (Phase 1-7 done in
  `private/file-size-reform/`). Execution begins next session.

## Cycle summary (canonical — survives private/ absence)

1. **Cycle 1** — Land ADR-0099 + rule file + script + lesson amendment (docs+script, gate-skipped)
2. **Cycle 2** — Wire scripts/check_split_smell.sh into gate_commit.sh (informational, non-failing)
3. **Cycle 3** — Land ADR-0100 (rollback notice for 0095/0096/0097)
4. **Cycle 4** — Execute ADR-0097 rollback: re-incorporate verify into regalloc.zig; delete regalloc_verify.zig (~675 LOC after)
5. **Cycle 5** — Land ADR-0101 + extract init_expr.zig:
   - 5a: create init_expr.zig with copied helpers (sections.zig still has originals)
   - 5b: re-point sections_element/codes/data at init_expr.X
   - 5c: remove duplicates from sections.zig; sections.zig delegates to init_expr too
6. **Cycle 6** — Verification + handover refresh + acceptance criteria check
7. **Cycle 7 (optional)** — audit_scaffolding §B/§J + LOOP.md + ADR template amendments
8. **Cycle 8 (optional)** — next-D-141 guidance update

Acceptance findings: 4 expected (api/wasm.zig hub, testFenceTableFill N4 dup, inst_neon N3 informational, regalloc_compute N1 test-context carve-out).

## See

- [`private/file-size-reform/README.md`](../private/file-size-reform/README.md) — detailed workspace (gitignored)
- [`private/file-size-reform/07-execution-plan.md`](../private/file-size-reform/07-execution-plan.md) — full 8-cycle plan
- [`private/file-size-reform/08-self-review-fixes.md`](../private/file-size-reform/08-self-review-fixes.md) — review findings + applied fixes
- [ROADMAP](./ROADMAP.md) §9.12 — F/G/H/I open
- [`debt.md`](./debt.md) — D-055 only `now`
- [`lessons/INDEX.md`](./lessons/INDEX.md)
