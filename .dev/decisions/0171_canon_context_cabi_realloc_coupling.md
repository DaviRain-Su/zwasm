# ADR-0171 — CanonContext + cabi_realloc: the one core coupling

**Status**: Accepted (2026-06-07)
**Scope**: CM campaign chunk B1 (`.dev/component_model_plan.md` Phase B).
Implements the single core-runtime coupling identified in
`component_model_survey.md` §4 ("the 4 hardest pieces", piece 4). Within
ADR-0170's mandate; no ROADMAP §1/§2/§4 deviation.

## Context

The canonical ABI lifts/lowers component-level values to/from a core
module's linear memory. Aggregate values (string, list, record, …) that
don't fit the flattened register form must be written INTO guest memory,
which requires allocating guest memory — the `cabi_realloc` contract
(`CanonicalABI.md`): a core function `(old_ptr, old_size, align, new_size)
-> new_ptr` the guest exports so the host can allocate in the guest's
allocator (not a separate host arena, which the guest couldn't free).

This is the ONLY place the new Zone-2 component layer must reach back into
the core runtime. v1 (`canon_abi.zig:517`) modelled `cabi_realloc` as a
**host-side** Zig callback (`ReallocFn` stored on `CanonContext`, with a
bump-allocator fallback) — pragmatic but a spec divergence: the spec's
`cabi_realloc` is a guest core export, so allocation must run the guest's
own allocator via a core invoke.

## Decision

`canon.zig` defines `CanonContext` holding (a) the guest linear memory
slice and (b) an **injected realloc callback** — a `*const fn(ctx:
*anyopaque, old_ptr, old_size, alignment, new_size) ReallocError!u32`
plus an opaque ctx pointer. canon.zig NEVER imports the core runtime; the
higher orchestration layer (chunk B6) installs a callback that invokes the
guest's `cabi_realloc` export via `Runtime.invoke`. This is the
Zone-dependency **vtable injection** pattern (`zone_deps`: lower declares
the fn-pointer type, higher installs it) and keeps the spec-conformant
"realloc runs in the guest" property WITHOUT canon.zig depending upward.

The component runtime **`Value`** is a type DISTINCT from `runtime.Value`
(`single_slot_dual_meaning`): a component value carries interface-level
semantics (a `char` is a Unicode scalar, a `string` owns guest bytes),
whereas the *flattened* lowered form IS `runtime.Value` (what gets passed
to the core invoke). So `lower: component.Value -> []runtime.Value` and
`lift: []runtime.Value -> component.Value`.

B1 implements the flat scalar primitives (bool / s8..u64 / f32 / f64 /
char — each flattens to ONE core value, no memory touch); the realloc
callback is scaffolding exercised first in B3 (string). Size/align/
discriminant machinery + flags/enum + boundary fixtures land in B2.

## Alternatives rejected

- **v1 host-side realloc** (Zig bump allocator over the guest buffer):
  rejected — the guest can't reclaim host-arena allocations, and lowered
  aggregates returned to the guest would leak / alias. Spec wants the
  guest allocator.
- **canon.zig imports the core `Instance` directly**: rejected — upward
  Zone dependency (Zone-2 feature reaching the runtime), breaks the
  "component layer drives the core as a black box" property (survey §"v1
  as the existence proof").

## Consequences

- canon.zig stays free of core imports; testable with a mock realloc.
- B6 owns the one real wiring (callback → guest `cabi_realloc` invoke).
- Revisit if a guest omits `cabi_realloc` but exports only flat-scalar
  funcs (legal — no allocation needed); the callback stays un-invoked.
