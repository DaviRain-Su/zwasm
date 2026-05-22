# 0098 — Extract regalloc compute family into `regalloc_compute.zig`

- **Status**: Closed (§9.12-A DONE)
- **Date**: 2026-05-21
- **Author**: autonomous /continue loop (D-141 per-file ADR series, post-ADR-0097)
- **Tags**: file-layout, refactor, zone-2, regalloc, file-size-cap

## Context

`src/engine/codegen/shared/regalloc.zig` is at **1274 LOC**
post-ADR-0097 (verify extraction). Still 27% over the 1000-LOC
soft cap. ADR-0097 was Step 1 of the compute/verify split; this
ADR is Step 2 — extract the compute family + its tests to
`regalloc_compute.zig`, dissolving the WARN.

## Decision

Move from `regalloc.zig` to new `regalloc_compute.zig`:

**Code**:

- `forbiddenMaskForVreg` (private, ADR-0077 fence helper).
- `slotForbidden` (private, inline).
- `validateRegallocOpScratchReservation` (pub, comptime validator).
- `max_slots` constant (pub).
- `ActiveEntry` (private struct).
- `compute()` wrapper + `computeWith()` (the LSRA algorithm).
- `computeSpillOffsets` (private, ADR-0053 spill-frame helper).
- `max_reg_slots_gpr_default` (private constant).

**Tests** (compute / spill_offsets / computeSpillOffsets / fence /
validateRegallocOpScratchReservation / compute+shape_tags
integration):

- 7 "compute:" tests (LSRA basics).
- 2 "compute: ... shape_tags" tests.
- 2 "spill_offsets:" tests.
- 3 "computeSpillOffsets:" tests.
- 1 "compute: SIMD function" test.
- 4 "fence:" tests.
- 3 "validateRegallocOpScratchReservation:" tests.
- `testFenceTableFill` helper.

**Stay in `regalloc.zig`**: Error, ScratchReservationFn, Slot,
ShapeTag, Allocation struct + methods, deinit, all re-exports
(populateShapeTags, VregClass, verify, verifyWith, VerifyError,
plus new re-exports of compute/computeWith/validateRegallocOpScratchReservation/max_slots),
Allocation method tests, populateShapeTags integration tests.

### Implementation shape

Same as ADR-0097: cross-file circular import resolved via Zig
lazy import (regalloc_compute imports regalloc for Error,
ScratchReservationFn, Allocation, ShapeTag; regalloc imports
regalloc_compute for re-exports).

External API surface unchanged.

## Alternatives

1. **Move only the code, leave tests in regalloc.zig** —
   Rejected. Tests for compute belong with compute per
   edit-locality logic. Moving them along brings regalloc.zig
   under the soft cap; leaving them keeps WARN.

2. **Bundle into one mega-file with verify (re-merge ADR-0097)** —
   Rejected. Two-file split (compute / verify) is the cleaner
   ADR-0083 / ADR-0089 / ADR-0095 / ADR-0096 precedent: one
   sibling per coherent sub-phase.

## Consequences

**Positive**:

- regalloc.zig: 1274 → ~620 LOC (under 1000-LOC soft cap; D-141
  entry's `shared/regalloc.zig` slot clears).
- regalloc_compute.zig is a coherent ~660 LOC module: LSRA
  algorithm + fence + spill-offsets + their regression tests.
- Zero caller migration.

**Negative**:

- `testFenceTableFill` helper duplication retired — testFenceTableFill
  now lives only in regalloc_compute.zig. (regalloc_verify.zig
  already has its local dup per ADR-0097.)
- One additional file under `src/engine/codegen/shared/`.

**Neutral**:

- Cross-file circular import resolved via Zig lazy import
  (same shape as ADR-0095/0096/0097).
- Test gate (`zig build test`) asserts behaviour neutrality.

## References

- ADR-0097 — verify extraction (Step 1; this ADR is Step 2).
- ADR-0090 — populateShapeTags extraction.
- ADR-0092 — VregClass extraction.
- ADR-0083 / ADR-0095 / ADR-0096 — cross-file struct-method
  precedents.
- D-141 — file-size soft-cap proliferation.
- ROADMAP §A2 — file-size cap policy.
- ADR-0077 — op_scratch_reservation_table (the fence extracted
  here).
- ADR-0060 — call-crossing spill (force_spill_threshold).
- ADR-0037 — LIFO free-pool LSRA algorithm.
- ADR-0053 — v128 spill-frame alignment (computeSpillOffsets).

## Revision history

- 2026-05-21 — Initial draft (Proposed → Accepted same cycle;
  behaviour-neutral refactor; test gate asserts neutrality).

- 2026-05-22 (`006f0d6d`) — Status: Accepted → Closed (§9.12-A DONE).
