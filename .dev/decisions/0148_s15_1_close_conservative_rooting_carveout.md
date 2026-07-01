# 0148 — §15.1 closes on non-moving reclamation + conservative rooting; precise GcRootMap carved out

- **Status**: Accepted (2026-06-04; autonomous re-scope per ADR-0132 carve-out)
- **Date**: 2026-06-04
- **Author**: claude (autonomous, /continue bundle 15.1-gc-reclamation close)
- **Tags**: Phase 15, GC, reclamation, precise rooting, GcRootMap, §12.5, D-211, D-258, ROADMAP §18
- **Amends**: ROADMAP §15.1 row + narrative (scope split); ADR-0135 (the "precise
  rooting + reclamation land together" premise); ADR-0141 (§12.5 AOT stack-map
  co-definition timing); `.dev/debt.yaml` D-211 (re-scoped) + D-258 (filed)
- **Authorised-by**: ADR-0132 (autonomous re-scope when a phase's scope references
  genuinely-later / unscheduled work)

## Context

ROADMAP §15.1 as written bundles three things: (a) free-list reuse / compaction,
(b) a `zir.GcRootMap` stack-map root walker (precise rooting, ex-§11.4 / D-211,
co-defined with the §12.5 AOT stack-map per ADR-0141), and (c) a conservative
native-stack scan (ADR-0128 §2).

ADR-0135's safety argument is "a missed root can only UAF once reclamation frees
objects, so rooting must land WITH reclamation." That argument is satisfied by
the **conservative** rooting — ADR-0128 §2 states plainly that a **non-moving**
collector (which zwasm is) needs *only* a conservative native-stack scan, **not**
precise stack maps. The precise `GcRootMap` walker becomes load-bearing only for a
**moving / compacting** collector (to relocate pointers) or for **AOT GC-root
serialization** (§12.5 `.cwasm` stack-map, itself deferred). zwasm commits to
neither today.

The §15.1 reclamation bundle delivered (chunks 1a–2, SHAs `5de51a69` →
`be4357be`): `nativeStackHigh` + object-start-validated conservative native-stack
scan (1b) + heap-pressure collection trigger (1c, ADR-0146) + external free-list
reclamation with bounded-cursor proof (2, ADR-0147).

## Decision

**§15.1 closes on non-moving reclamation + conservative rooting.** The precise
`GcRootMap` stack-map walker and the §12.5 AOT GC-root serialization are **carved
out** of §15.1 — they are not required for the non-moving collector's correctness
(ADR-0128 §2) and have no committed consumer.

- §15.1 row + narrative re-scoped to "GC reclamation + **conservative** rooting
  (non-moving, ADR-0128 §2)"; the precise-rooting / AOT-stack-map clause is
  forward-referenced to **D-211** (precise rooting, barrier updated from
  "Phase-15 reclamation" — now landed — to "a moving collector OR AOT GC-root
  serialization is implemented").
- The JIT alloc trampoline (`jit_abi.jitGcAlloc`) does not yet drive a collection:
  it runs on a separate `*JitRuntime` whose roots are native-stack/register-resident
  (no interp operand buffer), so `root_scope.maybeCollect` (which walks a `*Runtime`)
  cannot be mirrored verbatim — it needs a JIT-flavoured root path. Tracked as
  **D-258** (interp reclamation is the §15.1 deliverable; a mixed workload still
  reclaims JIT-allocated dead objects whenever the interp path triggers, since the
  sweep walks the whole slab).

## Rejected alternatives

- **Block §15.1 on the precise GcRootMap walker** — would couple a delivered,
  correctness-complete non-moving reclaimer to moving-collector / AOT machinery
  that has no committed consumer, contradicting ADR-0128 §2.
- **Wire D-258 (JIT trigger) before closing** — the JIT root model differs
  (native-stack scan + globals, no operand walk); it is its own chunk with
  JIT-execution test surface, not a one-line mirror. Deferring it does not leave
  §15.1's deliverable (bounded cursor via reclamation, demonstrated) incomplete.

## Consequences

- §15.1 flips `[x]`; §15.2 (coalescer detection) opens. Phase 15 stays IN-PROGRESS.
- D-211 remains open (re-scoped barrier); D-258 is `now` debt. Neither blocks the
  §15.2–§15.6 performance + ClojureWasm track.
- If a moving collector is ever adopted, the conservative scan must be upgraded to
  precise (D-211) BEFORE relocation — ADR-0128 §2 invariant preserved here as the
  discharge predicate.
