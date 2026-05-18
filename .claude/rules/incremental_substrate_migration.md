---
description: "Incremental process discipline for §9.12-B Q3 C-adopted per-op file migration + DCE extension across all layers. 1 chunk = 1 op or 1 layer; pinpoint revert OK; spike heavily + discard dead-end approaches."
paths:
  - "src/instruction/**/*.zig"
  - "src/feature/**/*.zig"
  - "src/ir/dispatch_collector.zig"
  - "src/cli/args.zig"
  - "src/api/wasm.zig"
  - "src/wasi/**/*.zig"
---

# Incremental substrate migration

> **Status**: skeleton (2026-05-19). Justified by ADR-0073 (Proposed;
> build-option DCE substrate). Completed across §9.12-A through §9.12-B.

## The rule

Q3 C-adopted completion of Phase 9 (§9.12-B) MUST proceed **incrementally**:

### 1 chunk = 1 unit

- Per-op file conversion of 1 op (1 ZirOp tag → 1 file `<op>.zig`)
- Declarative-form conversion of 1 layer (any one of CLI / c_api / WASI)
- Implementation of 1 enforcement script (skeleton → working)

### Pinpoint revert

- On failure, `git revert <sha>` the commit; do not amend (per `/continue` LOOP.md discipline)
- Add a "rolled back, ADR-NNNN" entry to the ratchet history yaml
  (skip_impl_history.yaml)
- Re-spike with a different approach

### Spike heavily + discard

- Experiment under `private/spikes/<slug>/` (see `.claude/rules/spike_lifecycle.md`)
- If adopted: `Status: merged-into-prod` + production commit cite
- If rejected: `Status: rejected` + lesson is mandatory

### Progress tracker (machine-readable)

- Update the sub-row × op × layer matrix in `.dev/p9_completion_progress.yaml`
- On each chunk close, the commit adds a row to the yaml
- Check live status via `bash scripts/p9_completion_status.sh`

## Why

"Spare no effort" does not mean "force everything done in one shot"; it means
"never give up, try as many times as needed." Proceeding incrementally makes
the judgement of discarding dead-end approaches cheap — you don't hold onto them.
The quality of Phase 9 completion is measured by per-op single-file conversion +
5-axis handler consolidation + build-option DCE attainment; these can be advanced
one op at a time.

## Anti-patterns to avoid

- ❌ "Q3 C adoption is a huge undertaking, so let's write all ops in one shot"
  (= revert on failure becomes massive)
- ❌ "Creating a spike just to discard it is wasteful; we'll figure it out mid-implementation"
  (= the role of a spike is to lower judgement cost)
- ❌ "Hide failed chunks via amend" (= history becomes invisible, making root-cause hard)
- ❌ "Track progress in memory / write it in handover narrative" (= the live yaml is
  the primary source of truth)

## Enforcement

- This rule auto-loads on the listed paths
- `scripts/check_subrow_exit.sh` (§9.12-A; literal verification of exit conditions
  on chunk close)
- `.dev/p9_completion_progress.yaml` (§9.12-A; seed)

## Related

- ADR-0073 (build-option DCE substrate; §9.12-B completion target)
- Master plan §8 (incremental process + spike operation)
- `.claude/rules/spike_lifecycle.md`
- `.claude/rules/extended_challenge.md` Step 4
- `.claude/rules/no_handover_predictions.md`
