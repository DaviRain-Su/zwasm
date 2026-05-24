# 0092 — Extract vreg storage classifier to `regalloc_vreg_class.zig`

- **Status**: Closed (2026-05-21, draft + impl landed same cycle)
- **Date**: 2026-05-21
- **Author**: autonomous /continue loop (D-141 per-file ADR series, post-ADR-0091)
- **Tags**: file-layout, refactor, zone-2, codegen, regalloc, file-size-cap

## Context

`src/engine/codegen/shared/regalloc.zig` was 1527 LOC after
ADR-0090 (still over soft cap). The lesson
[`2026-05-21-pure-data-extraction-via-reexport`](../lessons/2026-05-21-pure-data-extraction-via-reexport.md)
survey checklist identifies the second-largest cohesive
sub-block: `VregClass` enum + `vregClassByDef` +
`vregClassOfOp` at lines 728–860 (~117 LOC + 15-line doc).

The block:

- `pub const VregClass = enum { gpr, fpr, v128 };` (single line)
- `pub fn vregClassByDef(func, target_vreg) VregClass`
  (18 LOC; walks func.instrs to find the def-site op of the
  target vreg).
- `fn vregClassOfOp(ins, func) ?VregClass` (98 LOC; per-op
  classifier — large `switch (ins.op)` over Wasm op tags).

No methods on VregClass. `vregClassOfOp` is private (no `pub`)
— only called by vregClassByDef within the block. External
callers reach only `regalloc.VregClass` + `regalloc.vregClassByDef`.

Origin: D-097 / d-17 per the doc comment — vreg storage class
classification was introduced to distinguish GPR vs FPR vs v128
vregs for the per-class register pool selection.

## Decision

Move the block to a new sibling
`src/engine/codegen/shared/regalloc_vreg_class.zig`. Re-export
from `regalloc.zig`:

```zig
const vreg_class_mod = @import("regalloc_vreg_class.zig");
pub const VregClass = vreg_class_mod.VregClass;
pub const vregClassByDef = vreg_class_mod.vregClassByDef;
```

Note: `vregClassOfOp` is NOT re-exported — it's only used
internally by `vregClassByDef` within the sibling, and remains
non-pub. This preserves the encapsulation of the per-op switch
as an implementation detail.

| File | Contents | Approx LOC |
|---|---|---|
| `src/engine/codegen/shared/regalloc.zig` (revised) | All other regalloc machinery (compute / verify / spill / allocation / scratch-reservation). Re-exports VregClass + vregClassByDef from sibling. | ~1403 |
| `src/engine/codegen/shared/regalloc_vreg_class.zig` (new) | 13-line header + VregClass enum + vregClassByDef + vregClassOfOp. | ~148 |

**Zero caller migration** — 2 external caller files
(`arm64/op_control.zig` and `x86_64/op_control.zig`, 4 call
sites total at the `.fpr` merge-check sites) reach
`regalloc.vregClassByDef` through the re-export identically.

## Alternatives considered

### Alternative A — Combine with regalloc_shape_tags.zig

- **Sketch**: keep all "vreg-property" helpers in one sibling
  (ShapeTag + populateShapeTags + VregClass + vregClassByDef).
- **Why rejected**: ShapeTag and VregClass are independent
  classifications (ShapeTag = scalar/v128 for emit-dispatch
  shape; VregClass = gpr/fpr/v128 for storage-class
  selection). Combining them would couple unrelated concerns;
  the sibling file's purpose becomes "vreg-related anything"
  rather than a focused single-concept extraction.

### Alternative B — Keep monolith + FILE-SIZE-EXEMPT

- **Sketch**: regalloc.zig stays at 1527.
- **Why rejected**: the 117-LOC extraction is mechanically
  cheap; precedent (ADR-0090) directly applies; minor reduction
  is still real reduction.

## Consequences

- **Positive**:
  - regalloc.zig drops 1527 → 1403 LOC. Still over soft cap
    but -124 reduction.
  - VregClass + classifier becomes findable by file name
    (someone looking for "where is the per-vreg storage class
    determined" reaches `regalloc_vreg_class.zig` immediately).
  - Zero caller migration cost.
- **Negative**:
  - regalloc.zig still over soft cap (1403 > 1000). Further
    extraction requires ADR-grade design choice
    (compute/verify/spill axis decomposition).
- **Neutral / follow-ups**:
  - Pattern composes cleanly with the 6 prior re-export
    extractions (ADR-0082/0086/0087/0088/0090/0091) — this is
    the 7th instance.

## References

- ADR-0090 — regalloc_shape_tags.zig (direct precedent; same
  re-export pattern for the first cohesive sub-block in
  regalloc.zig).
- ADR-0082/0086/0087/0088/0091 — earlier re-export
  applications.
- Lesson
  [`2026-05-21-pure-data-extraction-via-reexport`](../lessons/2026-05-21-pure-data-extraction-via-reexport.md)
  — survey checklist applied here.
- D-097 / d-17 — the vreg-storage-class origin (FPR merge MOV
  precision-preservation issue).
- D-141 — file-size soft-cap proliferation.
- ROADMAP §A2 — file size soft (1000) / hard (2000) caps.

## Revision history

| Date       | SHA          | Note                                    |
|------------|--------------|-----------------------------------------|
| 2026-05-21 | `e8c8c6bf`   | Initial draft + impl landed same cycle. regalloc.zig 1527 → 1403 LOC (-124); regalloc_vreg_class.zig 148 LOC new. Zero caller migration. vregClassOfOp stays non-pub (encapsulation preserved). Test gate cohort + lint green. |
