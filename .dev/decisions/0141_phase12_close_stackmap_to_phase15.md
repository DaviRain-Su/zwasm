# 0141 — §12.5 (`.cwasm` stack-map section) re-sequenced to Phase 15; §12.P closes the AOT core without it

- **Status**: Accepted (2026-06-03; autonomous re-sequencing per ADR-0132)
- **Date**: 2026-06-03
- **Author**: claude (autonomous Phase-12 close)
- **Tags**: Phase 12, §12.5, §12.P, AOT, `.cwasm`, stack-map, GC, Phase 15, D-211, ADR-0117, ADR-0135, ROADMAP §18
- **Amends**: ROADMAP §12 (§12.5 → Phase 15; §12.P exit drops the stack-map criterion); Phase Status widget
- **Authorised-by**: ADR-0132 (autonomous re-sequence when a row's exit references genuinely-later work);
  mirrors ADR-0135 (§11.4 GC-rooting → Phase 15)

## Context

§12.5 = "`.cwasm` stack-map section: per-callsite entries serialised **in the same shape as JIT-mode populates
them**, gated `Module.needs_gc_heap`" (ADR-0117 I4). The JIT side does NOT populate stack-maps yet:
`zir.GcRootMap` is a zero-field placeholder (`src/ir/zir.zig`); per-callsite root-slot population is Phase 15
precise rooting (ADR-0135, ADR-0128 §2 "rooting becomes load-bearing only when reclamation lands"; D-211). So
there is no shape to serialise — defining the `.cwasm` entry layout now would be speculative (a format committed
before its producer exists), and the layout must co-define with the Phase-15 `GcRootMap`.

This exactly mirrors §11.4 (GC-on-JIT precise rooting), which ADR-0135 re-sequenced to Phase 15 for the same
reason (untestable without reclamation). §12.5 is the AOT-format half of the same Phase-15 rooting work.

Meanwhile Phase 12's AOT **core is complete + verified**: `zwasm compile`/`run *.cwasm` loader (§12.1), JIT↔AOT
differential equivalence (§12.2), toolchain cross-compile (§12.3), stateful-COMPUTE execution — globals + memory
+ tables/`call_indirect` (§12.3b, ADR-0140), and cold-start ≥30% (§12.4: 6/6 SIMD fixtures 33–37% AOT-faster).

## Decision

1. **§12.5 → Phase 15**: the `.cwasm` stack-map section lands WITH Phase-15 precise rooting, where `GcRootMap`
   gets its shape — the AOT serialisation co-defines with the JIT-mode populated shape (ADR-0117 I4 honoured
   then, not speculatively now). Row marked `[~] moved to Phase 15`, preserved for citation lineage.
2. **§12.P exit re-scoped**: drop the "stack-map section" criterion (forward-ref Phase 15). Phase 12 closes on
   its AOT core: loader + differential + cross-compile + stateful-compute + cold-start ≥30%, + the 3-host
   reconcile. WASI/host imports already deferred (ADR-0140 / D-251); GC stack-map now deferred (this ADR).
3. **Close Phase 12** (widget → DONE; open Phase 13).

### Rejected alternatives

- **Define the `.cwasm` stack-map layout now (empty/forward-compat slot)** — speculative: the entry shape must
  match what Phase-15 `GcRootMap` populates; guessing it risks a format re-bump. Co-defining in Phase 15 is one
  format change, not two.
- **Keep Phase 12 open until Phase 15** — the AOT core is done + shippable for Wasm 1.0/2.0 compute; blocking
  the phase close on a GC-only, Phase-15-coupled format slot stalls Phase 13 needlessly (cf. §11.4 precedent).

## Consequences

- ROADMAP: §12.5 → `[~] moved to Phase 15`; §12.P exit text drops stack-map + → `[x]`; widget Phase 12 DONE /
  Phase 13 IN-PROGRESS; §13 task table expanded.
- Phase 15 scope gains: GC-on-JIT precise rooting (§11.4, ADR-0135) + `.cwasm` stack-map section (§12.5, this
  ADR) — both the rooting work, JIT + AOT halves together.
- 3-host reconcile: Phase-12 AOT exec tests skip Win64 (`skip.phaseEnd`); the windowsmini test-all reconcile +
  the cross-compile gate (x86_64-windows-gnu) cover the Win64 surface (no new Win64-exec paths in Phase 12).
- No code change in this ADR (ROADMAP + handover + widget).

> **Doc-state**: ACTIVE
