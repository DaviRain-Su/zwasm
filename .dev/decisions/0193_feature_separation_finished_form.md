# ADR-0193 — Feature-separation finished-form: unify the WASI version axis + reify component-P2/P3 as registration

- Status: **Proposed** (USER-steered design, 2026-06-16; implementation gated on user review — this is a §4
  architecture change the user explicitly asked to *design before coding*)
- Date: 2026-06-16
- Deciders: user-flagged (debt D-462); investigation loop-executed
- Relates: ADR-0181/0182 (build flags), ADR-0023 §3 (feature `register()` pattern), ADR-0129 (binary-size
  dispatch gating), ADR-0187-0191 (CM-async / P3). ROADMAP §4.6 (feature flags) — this is a §4.6 deviation, so
  the ADR precedes any code per §18.

## Context

The maintainer once carefully separated runtime features at build time + runtime. As WASI Preview-2 (Component
Model) then Preview-3 (async, D-335) landed, the separation eroded. The **finished-form preference** (lesson
`feature-separation-finished-form-preference`, user-stated) ranks the *mechanism* of separation, LEFT = more
finished:

> **directory > file (declared metadata + central comptime collector) > function-cluster (one boundary) >
> comptime/runtime `if`-branch (`分岐散り`, least finished).**

Not every branch is a defect — some are genuinely unavoidable. The task is to tell the true finished form from the
unavoidable, and migrate realistically.

### Current state (investigation 2026-06-16, debt D-462)

Per-axis finished-form grade + biggest erosion:

| Axis | Grade | Mechanism today | Biggest erosion |
|---|---|---|---|
| Wasm spec level | B (good) | dir `src/instruction/wasm_{1,2,3}_0/` + per-file `wasm_level` metadata + central `dispatch_collector` | 9 conditional feature-module imports in `api/instance.zig:39-52` |
| Engine | B+ (clean) | dir `src/interp/` + `src/engine/codegen/{arm64,x86_64}/`; selected at instantiation | none |
| GC | B (placeholder) | `src/feature/gc/register.zig` (`enable_gc` + `register()`) | none yet (flag not scattered) |
| **WASI version** | **D+ (eroded)** | P1 in `src/wasi/`; **P2/P3 host in Zone-3 `src/api/component_wasi_p{2,3}.zig`, NOT in the metadata/registration scheme**; `WasiLevel={none,p1,p2,both}` has **no p3** | P2/P3 unselectable as versions; gated by a *separate* `-Dcomponent` bool |
| **Component** | **D (eroded)** | Zone-1 decoder walled in `src/feature/component/`, but Zone-3 orchestration sprawls (`api/component*.zig`); `-Dcomponent` bool gates it via a CLI runtime check (`cli/main.zig:296`) | two flags (`-Dwasi=p2` AND `-Dcomponent`) gate P2; contradictory combos unvalidated |

**Scattered `build_options.*` branch sites (≈11)** — classification:
- **Genuinely UNAVOIDABLE (~6)**: parser byte-level version gates (`parse/sections.zig` memory64 idx-type, EH tag
  section); CLI `--version` display (`cli/main.zig`); JIT-trace diagnostics (`entry.zig`, `platform/stack_limit.zig`);
  the interp subtype-accept arm (`interp/mvp.zig`, already size-gated per ADR-0129). These read a flag at a point
  where no structural boundary can exist (wire-level / display / diagnostic). **Accept as-is.**
- **STRUCTURALISABLE (~4-5)**: the `api/instance.zig` conditional feature imports → directory/registration
  discovery; the memory64 i64 emit path (`codegen/{arm64,x86_64}/op_memory.zig`) is already a full sub-emitter
  (`emitMemOpI64`) → move to a function-cluster `op_memory_i64.zig` registered by build predicate.

## Decision (target finished form)

**Single ordered WASI version axis, with the component runtime as its P2+ substrate, reified as Zone-1 feature
registration.**

1. `WasiLevel = enum { none, p1, p2, p3 }` — an **ordered tier** (drop the `both` wildcard; `p3 ⊇ p2 ⊇ p1`).
   Dispatch filter becomes `need > build_level → drop` (remove the `!= .both` special case at
   `dispatch_collector.zig:120`).
2. **The component runtime is gated by `wasi_level >= p2`, not a separate `-Dcomponent` bool.** P2 *is* the
   component substrate here; P3 = P2 + async. `-Dcomponent` is removed as an independent axis (or kept only as a
   deprecated alias mapping to `-Dwasi=p2`). This eliminates the two-flag overlap + the contradictory-combo class.
3. **Reify P2/P3 as Zone-1 feature registration** mirroring `src/feature/gc/register.zig`: new
   `src/feature/wasi_p2/register.zig` + `src/feature/wasi_p3/register.zig` declaring their level + a `register()`
   that wires host builtins, so the gate lives *with the feature* (file tier) instead of a Zone-3 CLI branch.
   Zone-3 keeps only thin orchestration (`api/component_wasi_glue.zig`).
4. **Structuralise the ~4 cheap branch sites** (instance.zig imports → registration; memory64 emit →
   `op_memory_i64.zig`); **explicitly accept the ~6 unavoidable** ones (document each with a one-line "why
   unavoidable" so future audits don't re-flag them).

## Consequences

- One coherent axis: build-time `-Dwasi` and runtime reachability agree; no `-Dwasi=p1 -Dcomponent=true`
  contradiction; P3 finally selectable. Component-import version checks become a single predicate.
- **Breaking build-flag change** (`-Dcomponent` removed/aliased; `WasiLevel` values change) — acceptable on this
  pre-release v2 branch (ADR-0156 surfaces are breakable), but it touches `build.zig`, `dispatch_collector`, CLI,
  and the component runner wiring (~5-8 files).
- Moves WASI/component from grade D → B (file-tier registration), matching the Wasm-level axis.

## Realistic phased migration (cheap + de-risking first; each phase independently green)

1. **P1 — add `.p3` + ordered-tier semantics** (non-folding): extend `WasiLevel` to `{none,p1,p2,p3}`, make the
   collector filter ordered, keep `both`→`p3` alias temporarily. Lowest risk; unblocks P3 selectability. (Add the
   contradictory-combo build validation here.)
2. **P2 — registration reification**: introduce `src/feature/wasi_p{2,3}/register.zig`; move host-builtin wiring
   out of the Zone-3 CLI branch into `register()`. Behaviour-preserving; characterization tests pin the WASI
   corpus (158/0/0) at every commit.
3. **P3 — fold `-Dcomponent` into `wasi_level >= p2`**: remove the standalone bool (or alias-deprecate). The
   breaking flag change; do last, after the axis is coherent.
4. **P4 — structuralise the cheap branch sites** (instance.zig imports, `op_memory_i64.zig`) + annotate the
   unavoidable ones. Independent, opportunistic.

Correctness-first (ADR-0153): each phase keeps the full WASI/component/spec corpora green; P2's behaviour-
preservation is pinned by characterization before the move.

## Open questions (for user review before implementation)

- Keep `-Dcomponent` as a deprecated alias, or hard-remove? (alias = gentler; remove = cleaner finished form.)
- Is a pure component-model-without-WASI build a real target? (If yes, `-Dwasi` is NOT the right sole axis and
  Option B — two documented orthogonal axes + a coherence invariant — is preferable. zwasm currently has no such
  consumer, so the single-axis Option A is recommended.)
