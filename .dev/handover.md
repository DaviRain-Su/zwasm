# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — FILE-SIZE REFORM Cycle 5c next

**Pickup is Cycle 5 sub-step 5c of the file-size discipline reform.**

1. Read `private/file-size-reform/07-execution-plan.md` §"Cycle 5"
   sub-step 5c (workspace gitignored; archived at 6c).
2. Execute sub-step 5c: in `src/parse/sections.zig`:
   - Replace internal `scanInitExpr(...)` calls with
     `init_expr.scanInitExpr(...)`.
   - Replace internal `readValType(...)` calls with
     `init_expr.readValType(...)` (in decodeTypes / decodeGlobals
     etc.; 4-5 sites).
   - Delete the `scanInitExpr`, `readValType`, `skipLeb128`
     function definitions from sections.zig (lines ~455-523).
   - Add `const init_expr = @import("init_expr.zig");` near top.
3. Then Cycle 6 (verification + lesson + archive).

**Recovery**: `grep -n 'scanInitExpr\|readValType\|skipLeb128' src/parse/sections.zig`
shows which sites + defs remain.

## Cycles landed (this session)

- **C1** (`a33e3dea`): ADR-0099 + rule + script + lesson + §A2 reframe.
- **C2** (`ce67bb45`): check_split_smell wired into gate + audit §J.
- **C3** (`a061d709`): ADR-0100 + 0095/0096/0097 Status updates.
- **C4** (`dc6edf9a`): ADR-0097 rollback executed.
- **C5a** (`d99d37bc`): ADR-0101 + init_expr.zig created.
- **C5b** (this commit): 3 siblings re-pointed at init_expr —
  sections_element (4 sites), sections_codes (1), sections_data (2).

check_split_smell: 6 findings (was 9; 3 sections N1-helper-circular
cleared). Residual 6: 4 expected + 2 sections N3-shallow
(sections_codes 58 LOC, sections_data 77 LOC — both Wasm §5.5.x
spec-axis siblings; P1 acceptable per ADR-0099 §D2 tie-breaker
even though substantive < 100). 5c does not change these.

## Background (short)

Post-D-141 retrospective: 3 of 15 sweep extractions don't satisfy
proper architectural standards. Reform plan: ADR-0099 (✅C1) →
gate wire (✅C2) → ADR-0100 (✅C3) → 0097 rollback (✅C4) →
ADR-0101 init_expr (✅C5a, ✅C5b; 5c pending) → verify + lesson +
archive (C6).

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

- なし。5c is mechanical (sections.zig internal-caller re-point
  + delete helper defs).

## See

- [`.dev/decisions/0099_file_size_discipline_reframe.md`](./decisions/0099_file_size_discipline_reframe.md)
- [`.dev/decisions/0100_rollback_invalid_d141_extractions.md`](./decisions/0100_rollback_invalid_d141_extractions.md)
- [`.dev/decisions/0101_init_expr_extraction.md`](./decisions/0101_init_expr_extraction.md)
- [`src/parse/init_expr.zig`](../src/parse/init_expr.zig)
- [`private/file-size-reform/07-execution-plan.md`](../private/file-size-reform/07-execution-plan.md)
- [ROADMAP](./ROADMAP.md) §9.12 F/G/H/I; §5 A2 reframed
- [`debt.md`](./debt.md) — D-055 only `now`
- [`lessons/INDEX.md`](./lessons/INDEX.md)
