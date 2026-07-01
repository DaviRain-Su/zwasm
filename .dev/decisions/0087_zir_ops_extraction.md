# 0087 — Extract `ZirOp` catalog into `zir_ops.zig`

- **Status**: Closed (2026-05-21, draft + impl landed same cycle)
- **Date**: 2026-05-21
- **Author**: autonomous /continue loop (D-141 per-file ADR series, post-ADR-0086)
- **Tags**: file-layout, refactor, zone-1, ir, file-size-cap

## Context

`src/ir/zir.zig` is **1244 LOC** — 24% over soft cap. Single
biggest contributor: the `ZirOp = enum(u16) { ... }` block at
lines 65–748 is **684 LOC of pure tag variants** covering Wasm
1.0, Wasm 2.0, Wasm 3.0 stubs, and `__pseudo.*` JIT ops. 55% of
the file is one enum.

Structural inventory:

- Lines 1–64: docstring + imports + small types (ValType,
  FuncType, TableEntry, BlockKind, BlockInfo).
- **Lines 65–748: `pub const ZirOp = enum(u16) {...};`** —
  the extraction target.
- Lines 750–1244: ZirInstr / Liveness / LiveRange / LoopInfo /
  ZirFunc (with its methods init/deinit/totalLocalCount/
  localValType) + other small types.

ZirOp has **no methods on the type itself** — purely variants
(verified via grep — methods at lines 1029+ are on ZirFunc, not
ZirOp). This makes it a clean pure-data extraction candidate,
same shape as ADR-0082's collected_ops tuple and ADR-0086's
codegen registry.

## Decision

Move ZirOp's `enum(u16) { ... }` block to a new sibling
`src/ir/zir_ops.zig`. zir.zig re-exports so all external callers
continue to reach `zir.ZirOp` identically.

| File | Contents | Approx LOC |
|---|---|---|
| `src/ir/zir.zig` (revised) | docstring + imports + small types + ZirInstr / Liveness / LiveRange / LoopInfo / ZirFunc + methods. Re-exports ZirOp from sibling. | ~566 |
| `src/ir/zir_ops.zig` (new) | 9-line header + the full `pub const ZirOp = enum(u16) {...}` block. | ~693 |

Re-export pattern (same as ADR-0086):

```zig
const zir_ops = @import("zir_ops.zig");
pub const ZirOp = zir_ops.ZirOp;
```

**Zero caller migration** — the validator / lower / interp / arm64
/ x86_64 / dispatch_collector / runner / etc. layers all reach
`zir.ZirOp` through the re-export. No `inst_fp`-style sed
migration needed (contrast ADR-0084 which had 127 caller sites).

## Alternatives considered

### Alternative A — Split ZirOp by Wasm version family (1_0 / 2_0 / 3_0 / __pseudo)

- **Sketch**: 4 sibling files, one per Wasm version cohort.
- **Why rejected**: ZirOp is a single enum — splitting it across
  files requires either (a) Zig's [WIP enum-from-merge feature,
  not in 0.16] or (b) defining the tags as `const` integers and
  losing exhaustive switch coverage. Both break the type's core
  property (single tag namespace + comptime exhaustiveness in
  dispatch switches). Same anti-pattern as ADR-0080 / ADR-0084
  Alternative A.

### Alternative B — Keep monolith + FILE-SIZE-EXEMPT marker

- **Sketch**: zir.zig stays at 1244; add `// FILE-SIZE-EXEMPT`
  per ADR-0063 §"Allowed patterns".
- **Why rejected**: zir.zig is not a uniform-adapter catalog
  (which is the FILE-SIZE-EXEMPT rationale per ADR-0075 §9.12-B
  / op_simd_int_cmp_lane.zig). It's a mixed module — ZirOp
  catalog + ZirInstr + Liveness + ZirFunc + 25 small types. The
  ZirOp catalog being large is incidental, not an
  architectural property of the file.

## Consequences

- **Positive**:
  - zir.zig drops 1244 → 566 LOC. Well under soft cap.
  - ZirOp catalog becomes findable by file name (someone
    looking for "where are the Wasm opcodes listed" reaches
    `zir_ops.zig` immediately).
  - Zero caller migration cost. Re-export pattern compounds
    cleanly with ADR-0082 / ADR-0086 precedent.
  - D-141 zir.zig slot closes.
- **Negative**:
  - zir_ops.zig is **693 LOC** — under soft cap, no issue.
- **Neutral / follow-ups**:
  - Future Wasm extensions (e.g., Wasm threads, GC, exception
    handling) add tags to zir_ops.zig directly — no zir.zig
    diff needed.

## References

- ADR-0082 — ir/dispatch_collector_ops.zig (sibling pure-data
  extraction in the same `src/ir/` directory).
- ADR-0086 — codegen dispatch_collector_ops.zig (same
  re-export pattern).
- D-141 — file-size soft-cap proliferation.
- ROADMAP §A2 — file size soft (1000) / hard (2000) caps.

## Revision history

| Date       | SHA          | Note                                    |
|------------|--------------|-----------------------------------------|
| 2026-05-21 | `50834b6f`   | Initial draft + impl landed same cycle. zir.zig 1244 → 566 LOC (-678); zir_ops.zig 693 LOC new. Zero caller migration (re-export). Test gate cohort + lint green. D-141 zir.zig slot closes. |
