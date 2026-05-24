# 0088 — Extract stackEffect catalog to `liveness_stack_effect.zig`

- **Status**: Closed (2026-05-21, draft + impl landed same cycle)
- **Date**: 2026-05-21
- **Author**: autonomous /continue loop (D-141 per-file ADR series, post-ADR-0087)
- **Tags**: file-layout, refactor, zone-1, ir, analysis, file-size-cap

## Context

`src/ir/analysis/liveness.zig` is **1192 LOC** — 19% over soft
cap. The dominant contributor (~43% of the file) is the
`stackEffect(op: ZirOp) ?StackEffect` function at lines 64–572 —
a **509-LOC giant switch** mapping each ZirOp variant to its
`(pops, pushes)` stack effect. Pure data masquerading as a
function; no methods, no state, no allocator.

Structural inventory:

- Lines 1–52: docstring, imports, constants, helper aliases.
- Line 53: `pub const StackEffect = struct { pops: u8, pushes: u8 };`.
- Lines 54–63: doc comment for `stackEffect`.
- **Lines 64–572: `pub fn stackEffect(op: ZirOp) ?StackEffect`** — extraction target.
- Lines 573+: `isControlFlow`, `compute`, `deinit`, `buildFunc`,
  and the actual liveness-analysis machinery.

External callers (verified via grep):

- `src/engine/codegen/shared/regalloc.zig:1037` —
  `if (liveness.stackEffect(ins.op)) |eff| { ... }` (1 call site).
- 2 comment references at regalloc.zig:727 and 1027 (no code
  impact).

Single call site + re-export pattern make this a zero-migration
extraction (same shape as ADR-0086 / 0087).

## Decision

Move `StackEffect` struct + its doc comment + the entire
`stackEffect` function (lines 53–572, ~520 LOC) into a new
sibling `src/ir/analysis/liveness_stack_effect.zig`.
`liveness.zig` re-exports both symbols.

| File | Contents | Approx LOC |
|---|---|---|
| `src/ir/analysis/liveness.zig` (revised) | docstring + imports + constants + isControlFlow + compute (main analysis) + deinit + helpers. Re-exports StackEffect / stackEffect from sibling. | ~679 |
| `src/ir/analysis/liveness_stack_effect.zig` (new) | 13-line header + import + StackEffect struct + 510-LOC stackEffect switch. | ~533 |

Re-export pattern:

```zig
const stack_effect_mod = @import("liveness_stack_effect.zig");
pub const StackEffect = stack_effect_mod.StackEffect;
pub const stackEffect = stack_effect_mod.stackEffect;
```

The `pub const stackEffect = ...` form aliases a function pointer
— supported in Zig 0.16 and zero-overhead (resolved at comptime).

**Zero caller migration** — `liveness.stackEffect(ins.op)` in
regalloc.zig continues to work through the re-export.

## Alternatives considered

### Alternative A — Split by Wasm version family (1_0 / 2_0 / 3_0)

- **Sketch**: `liveness_stack_effect_v1.zig` / `_v2.zig` etc.
- **Why rejected**: same as ADR-0087's Alternative A — a single
  exhaustive switch over an enum cannot be split across files
  without losing exhaustiveness checking. Splitting also forces
  the caller to know which file holds the op tag, defeating
  re-export simplicity.

### Alternative B — Keep monolith + FILE-SIZE-EXEMPT marker

- **Sketch**: liveness.zig stays at 1192 with the exempt marker.
- **Why rejected**: liveness.zig has substantial logic beyond the
  switch (compute / deinit / loop tracking) — it is not a
  uniform-adapter catalog (the ADR-0075 exempt rationale).
  Hiding the 510-LOC switch behind a marker would leave the
  remaining ~683 LOC of real logic visually swamped by data.

## Consequences

- **Positive**:
  - liveness.zig drops 1192 → 679 LOC. Well under soft cap.
  - The 510-LOC stack-effect table becomes findable by file
    name (the per-op data layer is structurally distinct from
    the analysis logic).
  - Zero caller migration cost.
  - D-141 liveness.zig slot closes.
- **Negative**: none material. liveness_stack_effect.zig at
  533 LOC is well under soft cap.
- **Neutral / follow-ups**: future Wasm extension ops (Wasm
  threads, GC, exception handling) extending the stack-effect
  catalog add tags to liveness_stack_effect.zig directly — no
  liveness.zig diff needed (consistent with ADR-0087's zir_ops
  pattern).

## References

- ADR-0087 — ir/zir_ops.zig (same re-export pattern, immediate
  precedent).
- ADR-0086 — codegen/dispatch_collector_ops.zig.
- ADR-0082 — ir/dispatch_collector_ops.zig.
- D-141 — file-size soft-cap proliferation.
- ROADMAP §A2 — file size soft (1000) / hard (2000) caps.

## Revision history

| Date       | SHA          | Note                                    |
|------------|--------------|-----------------------------------------|
| 2026-05-21 | `0f3f863f`   | Initial draft + impl landed same cycle. liveness.zig 1192 → 679 LOC (-513); liveness_stack_effect.zig 533 LOC new. Zero caller migration. Test gate cohort + lint green. D-141 liveness.zig slot closes. |
