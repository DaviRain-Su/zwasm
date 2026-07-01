---
name: handover-prediction-vs-evidence
description: Numeric predictions in handover ("Targets ~16 fails") drift from reality across sessions; rule + live-measurement script enforced.
type: lesson
---

# 2026-05-11 — handover prediction vs live evidence

## Context

§9.9-g-13 (preventive `emitV128IntCmpUnsigned` `dst==lhs`
alias fix). The prior handover wrote "Targets ~16 fails"
based on 9.9-g-12's hypothesis that the residual 16 cmp
fails were `dst==lhs` alias cases.

The next session (the autonomous /continue loop) trusted the
prediction, organised the chunk around it, implemented an
alias-safety fix, and discovered **only after running
test-spec-simd** that the 16 fails were actually
`i*x*.ne` family (PCMPEQ + PXOR-ones recipe with a
different bug) — entirely separate root cause.

The 9.9-g-13 fix was structurally correct (prevents a real
bug class with regression-detecting tests) but did not move
the FAIL count, because no current fixture exercises the
`ge_u/le_u + dst==lhs` alias.

## What this teaches

The drift came from three reinforcing failure modes:

1. handover's `Next candidates` listed numbers as if facts
   when they were stale hypotheses (no TTL marker)
2. session-start procedure had no "live verify" step before
   the per-task TDD loop
3. the same numeric breakdown was duplicated across
   handover + debt + commit body — only commit body is
   immutable, so the others drift

## Re-derivability

If the rule is skipped and "Targets ~N fails" creeps back:

- The number was true at SHA <X>, not at SHA <Y> (next
  session). There is no automatic invalidation.
- Without re-measuring, the next session might pick the
  wrong chunk (organize work around stale assumptions) and
  realize only after the test-gate runs.

## What landed (load-bearing this same commit)

- [`.claude/rules/no_handover_predictions.md`](../../.claude/rules/no_handover_predictions.md)
  — rule forbidding numeric predictions in mutable docs;
  documents Source-of-truth table per fact kind.
- [`scripts/p9_simd_status.sh`](../../scripts/p9_simd_status.sh)
  — live measurement script for §9.9; replaces
  duplicated numeric narrative in handover/debt.
- [`.dev/handover.md`](../handover.md) rewritten to
  minimal form (≤ 60 lines); cold-start procedure points
  at the script.
- [`.claude/skills/continue/SKILL.md`](../../.claude/skills/continue/SKILL.md)
  Resume Step 0.5b "Live status check" added.
- [`.dev/debt.md`](../debt.md) D-071 rewritten without
  numeric counts; speculative section prefixed
  `Hypothesis (verified at <SHA-or-date>):`.

## Citing

`67aa0025` (the source fix) + the same-batch chore commit
landing this rule + script + skill + handover + debt + lesson
edits.

## References

- ROADMAP §9.9 / 9.9-g-13 chunk record (records same drift
  + same-batch landing).
- prior lesson `2026-05-11-regalloc-lifo-vreg-alias-inplace-modify.md`
  (the structural pattern this chunk mirrors; not the
  drift-control rule).
