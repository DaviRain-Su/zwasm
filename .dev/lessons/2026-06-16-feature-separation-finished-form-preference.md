# Feature-separation finished-form preference: directory > file > function-cluster > branch

**Date**: 2026-06-16 (user-articulated design principle)
**Context**: WASI/Wasm version-separation audit (debt D-462).

When a feature/version/capability must be selectable or gated, the **finished
form (完成形) prefers STRUCTURAL separation over inline branching**. The
preference order, LEFT = more finished:

**directory  >  file  >  function-cluster  >  comptime/runtime `if`-branch**

- **directory** — e.g. `src/instruction/wasm_{1,2,3}_0/` (Wasm spec levels by
  dir). The cleanest: the separation IS the filesystem layout.
- **file** — per-file declared metadata (e.g. `pub const wasm_level: ?WasmLevel`,
  compile-error-enforced) consumed by ONE central comptime collector. Still
  finished-form: the gate lives with the feature, not scattered through callers.
- **function-cluster** — a feature's logic grouped behind one boundary
  (vtable / dispatch entry / a single module fn), so callers don't branch.
- **comptime/runtime `if`-branch** — `if (build_options.x) ...` scattered across
  call sites (`分岐散り`). LEAST finished; the gate is smeared over the codebase.

## Rule

When adding or auditing a gated feature, push it as far LEFT as the design
allows. zwasm's Wasm-level ops are near-finished (directory + file-metadata +
central collector); its component / WASI-P2/P3 host eroded RIGHTWARD to a
separate `enable_component` bool + scattered `if`s + runtime import-name
resolution — that erosion is the debt (D-462).

**But not every branch is a defect.** Some separations are genuinely unavoidable
as branches ("どうしても仕方がない部分"). The discipline is: (1) classify each
site as TRUE-finished-form-reachable vs unavoidable-branch via this hierarchy,
(2) design the true finished form for the reachable ones, (3) plan a REALISTIC
Phase-split migration — never force-fit a structural shape that fights the
problem. Investigate + design BEFORE refactoring (an ADR-grade decision when it
touches the build flags / level enums).
