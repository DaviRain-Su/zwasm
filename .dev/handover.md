# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — FILE-SIZE REFORM Cycle 5b next

**Pickup is Cycle 5 sub-step 5b of the file-size discipline reform.**

1. Read `private/file-size-reform/07-execution-plan.md` §"Cycle 5"
   sub-step 5b (workspace gitignored; archived at 6c).
2. Execute sub-step 5b: re-point the 3 siblings at `init_expr`:
   `sections_element.zig` (7 sites of `sections.scanInitExpr`),
   `sections_codes.zig` (`sections.readValType`), `sections_data.zig`
   (`sections.scanInitExpr`). Add `const init_expr =
   @import("init_expr.zig");` to each. After 5b: siblings no
   longer call `sections.X` helpers (N1 cleared for them).
3. Then sub-step 5c (delete duplicates from sections.zig; sections.zig
   internal callers also use init_expr).
4. Then Cycle 6 (verification + lesson + archive).

**Recovery**: `grep -r 'sections\.scanInitExpr\|sections\.readValType' src/parse/`
tells which call sites remain.

## Cycles landed (this session)

- **Cycle 1** (`a33e3dea`): ADR-0099 + rule + script + lesson +
  ROADMAP §A2 reframe.
- **Cycle 2** (`ce67bb45`): check_split_smell.sh wired into
  gate_commit.sh (informational) + audit §J.1 amend + §J.8 add.
- **Cycle 3** (`a061d709`): ADR-0100 + ADR-0095/0096/0097 Status updates.
- **Cycle 4** (`dc6edf9a`): ADR-0097 rollback — verify family
  re-incorporated into regalloc.zig; regalloc_verify.zig deleted.
- **Cycle 5a** (this commit): ADR-0101 Accepted +
  `src/parse/init_expr.zig` created (~115 LOC including tests).
  sections.zig keeps its copies during 5a.

check_split_smell now: still 9 findings (5a is purely additive;
findings drop in 5b/5c when sibling and internal callers re-point).

## Background (short)

Post-D-141 retrospective: 3 of 15 sweep extractions don't satisfy
proper architectural standards. Reform plan: ADR-0099 (✅ C1) →
gate wire (✅ C2) → ADR-0100 (✅ C3) → 0097 rollback (✅ C4) →
ADR-0101 init_expr extraction (in progress: ✅ 5a, 5b/5c pending)
→ verify + lesson + archive (C6).

## Active `now` debts

- **D-055** (mechanical, multi-cycle): emit_test_int has 27 sites
  pending. **Defer until reform lands.**

## Other queued work (post-reform)

1. §9.12-G `api/instance.zig` redesign (P3 evaluation per §D2).
2. §9.12-H bench baseline (Mac Wasm 2.0 + wasmtime comparison).
3. §9.12-I ADR/lesson curation closure (Phase 9 close).
4. D-055 continuation.
5. Remaining D-141 WARN files (most → EXEMPT marker per §D2).

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK.
- §9.12-F (D-141 sweep): 15 ADRs Accepted; net after reform =
  12 valid + 1 redesigned (init_expr) + 3 retired.
- §9.12-G/H/I: open.

## Open questions / blockers

- なし。5b is mechanical (3 file edits, 9 call sites total).

## See

- [`.dev/decisions/0099_file_size_discipline_reframe.md`](./decisions/0099_file_size_discipline_reframe.md)
- [`.dev/decisions/0100_rollback_invalid_d141_extractions.md`](./decisions/0100_rollback_invalid_d141_extractions.md)
- [`.dev/decisions/0101_init_expr_extraction.md`](./decisions/0101_init_expr_extraction.md)
- [`src/parse/init_expr.zig`](../src/parse/init_expr.zig)
- [`private/file-size-reform/07-execution-plan.md`](../private/file-size-reform/07-execution-plan.md)
- [ROADMAP](./ROADMAP.md) §9.12 F/G/H/I; §5 A2 reframed
- [`debt.md`](./debt.md) — D-055 only `now`
- [`lessons/INDEX.md`](./lessons/INDEX.md)
