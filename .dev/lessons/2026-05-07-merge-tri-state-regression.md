---
name: merge tri-state regression (D-035-c)
description: When widening `?T → [N]T + count` a count-only check loses the "did capture happen" information; need an explicit bool flag.
type: feedback
---

## What happened

D-035-c widened `Label.merge_top_vreg: ?u32` (single-result) to
`merge_top_vregs: [8]u32 + result_arity: u8` (multi-result) on
both backends. The single-result `?u32` had been doing
double-duty:

1. **Count axis** — null = no merge, set = 1 merge slot.
2. **Capture axis** — null = capture skipped, set = capture
   happened.

Conflating these axes worked because for arity ≤ 1 they
collapse to the same bit. The widening kept (1) (`result_arity
> 0`) but silently dropped (2). emitElse's capture is conditional
on `pushed_vregs.items.len >= arity` (dead-code zones, then-arm
break-outs leave the operand stack short), and emitEndIntra's
new gate `result_arity > 0` fired even when capture didn't.

Symptom: `test-spec-assert` 138/0/94 → 72/68/94 (68 regressions
in unreachable.0 + handcrafted_trap fixtures with dead-code if
patterns).

## Fix

Add an explicit `merge_captured: bool = false` field to Label.
emitElse sets it true only when capture actually happened;
emitEndIntra reads it as the merge-logic gate.

## Why it slipped past three-host gate

`test-spec-assert` is **not** wired into `test-all`. Filed as
D-040: wire it in (Mac-host guard if needed since aarch64 JIT
doesn't run on Linux/Windows).

## How to apply

When refactoring a polymorphic `?T` field to a count + buffer:

- List EVERY axis the `?T` was carrying (count, captured,
  initialized, valid, present-but-unset).
- Keep a dedicated bit/field per axis. Reusing the count
  field's `> 0` predicate as a stand-in for "captured" is a
  silent failure mode — it works for the simple case and
  breaks for any state where capture is conditional.

Citing: `.claude/rules/single_slot_dual_meaning.md` (the field
itself was a dual-axis slot; widening exposed the conflation).
Bug-fix-time grep (per `bug_fix_survey.md`) found the same
pattern in both backends — fixed in lockstep.

References: commit `a4b1510` (regression fix), commit
`13701e6` (introducing widening), `.dev/debt.md` D-040.
