# 0086 — Extract codegen op registry into `dispatch_collector_ops.zig`

- **Status**: Closed (2026-05-21, draft + impl landed same cycle)
- **Date**: 2026-05-21
- **Author**: autonomous /continue loop (D-141 per-file ADR series, post-ADR-0085)
- **Tags**: file-layout, refactor, zone-2, codegen, file-size-cap, dispatch-collector

## Context

`src/engine/codegen/dispatch_collector.zig` is **1887 LOC** —
89% over soft cap. This is the **Zone-2 codegen-side** dispatch
collector (per ADR-0074 two-zone split: Zone-1 IRAxis =
`{validate, lower, interp}` vs Zone-2 ArchAxis = `{arm64,
x86_64}`). Mirror of `src/ir/dispatch_collector.zig` (which
ADR-0082 already split).

Structural inventory matches ADR-0082's case at larger scale:

- Lines 86–877: `const arm64_<op> = @import("arm64/ops/wasm_X_Y/<op>.zig");`
  (arm64 imports, ~790 LOC)
- Lines 878–1227: `pub const collected_arm64_ops = .{ ... };`
  (arm64 tuple, ~350 LOC)
- Lines 1228–1229: section comment
- Lines 1230–1279: `pub const collected_x86_64_ops = .{ ... };`
  (x86_64 legacy-args tuple, ~50 LOC)
- Lines 1281–1287: per-ADR-0075 transitional comment block
- Lines 1288–1707: arch op imports + `collected_x86_64_ctx_ops`
  tuple (~420 LOC of imports + tuple)
- Lines 1708–1887: dispatcher framework
  (`validateArchOpModule`, `migratedArchOpCount`, `dispatch`,
  `dispatchX86_64Ctx`) + comptime validation block (~180 LOC)

Total: **~1620 LOC of pure registry data** (imports + 3 tuples) vs
**~265 LOC of dispatcher framework** (functions + validation).
86% of the file is pure data — same bimodal shape that motivated
ADR-0082.

## Decision

Mirror ADR-0082 exactly. Extract lines 86–1707 (arch op imports
+ all 3 `collected_*_ops` tuples) into a new sibling
`src/engine/codegen/dispatch_collector_ops.zig`. Original file
adds a 5-line re-export block to keep external callers
unchanged.

| File | Contents | Approx LOC |
|---|---|---|
| `src/engine/codegen/dispatch_collector.zig` (revised) | Type aliases (ArchAxis enum, WasmLevel/WasiLevel re-exports from ir_collector), validateArchOpModule, migratedArchOpCount, dispatch, dispatchX86_64Ctx, comptime validation. Imports the registry sibling + re-exports its 3 tuples. | ~264 |
| `src/engine/codegen/dispatch_collector_ops.zig` (new) | All per-arch op-module @import lines + the 3 `collected_*_ops` tuples + interspersed section comments. | ~1642 (with 22-line header) |

Re-export pattern (same as ADR-0082):

```zig
const ops_registry = @import("dispatch_collector_ops.zig");
pub const collected_arm64_ops = ops_registry.collected_arm64_ops;
pub const collected_x86_64_ops = ops_registry.collected_x86_64_ops;
pub const collected_x86_64_ctx_ops = ops_registry.collected_x86_64_ctx_ops;
```

External callers reach `dispatch_collector.collected_arm64_ops`
etc. identically — no API change.

### Why this ADR can land same-cycle as ADR-0082's pattern

The design is a direct mirror of ADR-0082. The only differences
from ADR-0082:

- 3 tuples to re-export instead of 1 (`collected_arm64_ops` +
  `collected_x86_64_ops` + `collected_x86_64_ctx_ops`).
- Sibling file needs `WasmLevel` / `WasiLevel` re-exports
  (ArchAxis-side validates against the same constraints
  Zone-1 side does via ir_collector).
- 1.8x larger registry mass (1622 LOC vs ADR-0082's ~900).

No novel design surface; the pattern is precedent-validated. Drafted
+ impl landed in single cycle.

## Alternatives considered

### Alternative A — Split each arch's registry to its own file

- **Sketch**: `dispatch_collector_arm64_ops.zig` + `dispatch_collector_x86_64_ops.zig`
  (separate files per arch).
- **Why rejected**: the 3 tuples share `validateArchOpModule`
  constraints and the comptime validation loop walks all 3
  together. Splitting them across two sibling files adds
  cross-file coupling for no semantic gain (per ADR-0082's
  Alternative A rejection — registry is one semantic unit).

### Alternative B — Keep monolith + raise soft cap

- **Sketch**: dispatch_collector.zig stays at 1887 LOC.
- **Why rejected**: precedent collapse (ADR-0079..ADR-0085 all
  reject cap-raise). The 265-LOC dispatcher framework is buried
  under ~1620 LOC of declarations; readability cost is real.

## Consequences

- **Positive**:
  - dispatch_collector.zig drops 1887 → ~264 LOC (-1623,
    largest single-file reduction in the per-file ADR series).
  - 265-LOC dispatcher framework becomes readable without
    scrolling past 1622 LOC of registry data.
  - D-141 codegen dispatch_collector slot closes.
  - Pattern composes: future Zone-2 ArchAxis additions (e.g.,
    riscv64 per ADR-0070-future) land in
    `dispatch_collector_ops.zig` directly.
- **Negative**:
  - dispatch_collector_ops.zig is **1642 LOC** — over soft cap.
    Per ADR-0082 precedent, this is acceptable for
    structurally-homogeneous data files (pure declarations +
    tuple literals, no logic to obscure). ADR-0063
    FILE-SIZE-EXEMPT marker available if reviewer eye-glaze
    surfaces.
- **Neutral / follow-ups**:
  - If registry grows past hard cap (would need ~360 more arch
    ops registered), version-family split is the natural next
    step (`dispatch_collector_ops_v1.zig` /
    `dispatch_collector_ops_v2.zig` / `dispatch_collector_ops_v3.zig`).
    Same as ADR-0082's deferred follow-up.

## References

- ADR-0082 — ir/dispatch_collector_ops.zig (direct precedent;
  Zone-1 IRAxis side).
- ADR-0074 — per-op-file Zone split (two-zone IRAxis vs
  ArchAxis structure this ADR's sibling realises).
- ADR-0075 — x86_64 ctx-tuple migration (defines `collected_x86_64_ctx_ops`
  as a separate tuple from `collected_x86_64_ops` during the
  legacy-vs-ctx-shape cutover).
- D-141 — file-size soft-cap proliferation.
- ROADMAP §A2 — file size soft (1000) / hard (2000) caps.

## Revision history

| Date       | SHA          | Note                                    |
|------------|--------------|-----------------------------------------|
| 2026-05-21 | `f0d91a82`   | Initial draft + impl landed same cycle. dispatch_collector.zig 1887 → 264 LOC (-1623); dispatch_collector_ops.zig 1642 LOC new. Test gate cohort + lint green. D-141 codegen dispatch_collector slot closes. |
