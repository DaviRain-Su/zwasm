# 0072 — Comment-as-invariant rule

- **Status**: Proposed
- **Date**: 2026-05-19
- **Author**: continue loop §9.12 substrate audit cycle
- **Tags**: phase-9, hygiene, rules, comment-discipline, regression-prevention

> **Status**: skeleton. To be expanded into a full draft in §9.12-pre.

## Context

How D-132 / D-133 (arm64 `op_table.zig` hardcoded X10/X11/X12 scratch registers)
came to light (details: `.dev/lessons/2026-05-16-regalloc-pool-scratch-overlap.md`):

- `op_table.zig` carried a comment stating "X10/X11/X12 are private scratch
  within the handler", but this was a prose-only invariant with no code-level
  enforcement
- regalloc used the same register slots as allocatable scratch
- A certain combination of corpus + nested-table-op led both parties to demand
  the same slot simultaneously, producing latent silent corruption (D-132 root
  cause)
- The lesson suggests that the prose invariant created an anti-pattern called
  **comment-as-invariant**

This is one of the 5 triggers identified in the Phase 9 completion substrate
audit Q5 (substrate hygiene). Details: `.dev/phase9_completion_substrate_audit.md`
§Q5.

## Decision

Introduce `.claude/rules/comment_as_invariant.md` (auto-load on `src/**/*.zig`):

> When writing an invariant in prose (i.e. "X is always Y" / "X is private
> scratch" / "X has alignment N", etc.), it MUST be paired with one of the
> following:
> (a) `comptime assert`
> (b) runtime `std.debug.assert`
> (c) lint script (`audit_scaffolding §G grep`)
> (d) deletion (= don't write it if it isn't needed)
>
> Violation example: the "X10/X11/X12 are private scratch" comment in
> `op_table.zig` (the origin of the D-132 / D-133 failure mode). Fix example:
> promote the relevant registers to named constants in `abi.zig` + extend the
> comptime disjointness check.

### Enforcement

- `.claude/rules/comment_as_invariant.md` (auto-load rule)
- Extend `audit_scaffolding §G` grep (strengthen D-132 / D-133 detection)
- D-133 sweep in §9.12-C (replace hardcoded register-numerals in op_table /
  op_memory with references via named constants)

## Alternatives considered

> Skeleton — to be expanded in §9.12-pre.

## Consequences

- **Positive**: prevents latent bugs of the same class (= regalloc / ABI
  invariants are enforced at the code level)
- **Negative**: existing comments need to be swept (carried out in D-133)
- **Neutral / follow-ups**: combine with the `bug_fix_survey` discipline
  (sibling sites grep) to raise catch coverage

## References

- `.dev/lessons/2026-05-16-regalloc-pool-scratch-overlap.md` (D-132 root cause)
- D-133 (op_table sweep — discharged in §9.12-C)
- ADR-0071 (Phase 9 substrate audit resolution; one of the Q5 deliverables)
- ADR-0018 (regalloc reserved set; prior art for comptime checks of the same
  class)
- `.dev/phase9_completion_substrate_audit.md` §Q5

## Revision history

| Date       | SHA          | Note                                                         |
|------------|--------------|--------------------------------------------------------------|
| 2026-05-19 | `<backfill>` | Initial skeleton — Q5 deliverable; full draft in §9.12-pre.  |
