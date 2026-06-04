# 0160 — JIT GC collection trigger: conservative-scan-only root model

- **Status**: Accepted (2026-06-05; §16.6 memory-safety, ADR-0156 endgame).
- **Date**: 2026-06-05
- **Author**: claude (Phase 16 完成形 memory-safety)
- **Tags**: gc, jit, memory-safety, rooting, conservative-scan, ROADMAP §16.6,
  D-258, D-261, ADR-0128, ADR-0146
- **Extends**: ADR-0146 (heap-pressure collection trigger — interp only) to the
  JIT alloc path; ADR-0128 §2 (spill-at-call conservative rooting model).

## Context

§15.1 / ADR-0146 wired the heap-pressure GC collection trigger into the **interp**
alloc helpers only: `struct_ops.allocateStruct` / `array_ops.allocateArray` →
`root_scope.maybeCollect(heap, gti, rt)`. The **JIT** GC-alloc trampolines
(`jit_abi.zig` `jitGcAlloc` / `jitGcAllocArray`) call `object_alloc.*` directly,
bypassing the trigger (D-258) — so a JIT-only allocation loop never collects, and
once free-list reuse landed (ADR-0147) the JIT path leaks relative to interp.

The interp `maybeCollect` calls `coll.bindRuntime(rt)` to walk **precise** roots
(operand stack / locals / globals) **plus** `coll.scan_native_stack = true`. But
`JitRuntime` (the per-instance struct the trampolines receive) carries only
`gc_heap` + `gc_type_infos_ptr` — **no `*Runtime`**. So the JIT path cannot
provide precise roots; it has only the conservative native-stack scan.

## Decision

**A JIT-triggered collection is conservative-native-stack-scan-only** (no
`bindRuntime`, no precise Runtime-root walk). Add `root_scope.maybeCollectJit(heap,
gti)` mirroring `maybeCollect` but without the Runtime root source, and call it at
the head of `jitGcAlloc` / `jitGcAllocArray` (before `object_alloc`), gated by
`heap.shouldCollect()`.

This is **correct** because GC-on-JIT execution is **pure-JIT**:

1. **No interp↔JIT call interleaving.** zwasm selects the engine per run (whole
   module interp OR whole module JIT); there is no per-call bridge that puts an
   interp frame (with roots in Runtime value buffers) below a JIT frame. So at a
   JIT collection point there are **no interp Runtime-buffer roots** to miss.
   (ADR-0128 §22: precise GC stack-map rooting is interp-only / deferred to D-211;
   the JIT's rooting IS the conservative scan.)
2. **Every live JIT GcRef is on the native stack at the trampoline CALL**
   (ADR-0128 §2 spill-at-call): a caller-saved register holding a live GcRef is
   spilled by the JIT body before the `CALL`; a callee-saved register holding one
   is saved into the `callconv(.c)` trampoline's own frame by its prologue. Either
   way the value sits in scannable stack memory while the collector runs inside
   the trampoline. The object-start-validated scan (`scanNativeStackRoots`) marks
   it.

The collector already supports this shape: `walkRootsImpl` runs
`scanNativeStackRoots` first, then `self.runtime orelse return` — a no-Runtime
collect is a native-scan-only collect.

### Verification gate (D-261, correctness-first)

The pure-JIT + spill-at-call guarantee is **load-bearing and was previously
unverified** (D-261). This ADR is accepted ONLY together with an **adversarial
test**: a JIT function that holds a GcRef across a collection-forcing
`struct.new`/`array.new`, in a shape that keeps the ref register-resident across
the trampoline CALL, asserting the object SURVIVES (not swept) — run under
ReleaseSafe on the 3-host gate. If that test ever fails, the spill model is
violated and this decision is void (escalate to D-211 precise rooting).

### Rejected alternatives

- **Thread `*Runtime` into `JitRuntime`** so the JIT path can do a precise walk.
  Rejected: the JIT does not keep roots in Runtime value buffers (it uses native
  regs/stack), so precise roots would be empty anyway; adding the field is dead
  weight + layout churn on the hot per-instance struct.
- **Fold `maybeCollect` into `object_alloc`.** Rejected: `object_alloc` is
  deliberately heap-only (shared by interp + JIT); it has no root context. The
  trigger must live at each call site so the caller supplies its own root model
  (interp = precise+conservative; JIT = conservative-only).

## Consequences

- `jitGcAlloc` / `jitGcAllocArray` now collect under heap pressure → no JIT-path
  leak relative to interp; closes D-258.
- The conservative-only model is the JIT rooting contract until D-211 (precise
  `GcRootMap` stack-map) lands; this ADR is the place that records why it is safe.
- D-261's adversarial test is the standing guard; a failure voids this decision.

## References

- ROADMAP §16.6; D-258 / D-261 (debt ledger). ADR-0128 §2 + §22 (conservative
  rooting + interp-only precise rooting). ADR-0146 (interp trigger), ADR-0147
  (free-list), ADR-0148 (rooting carve-out). `src/feature/gc/root_scope.zig`
  (maybeCollect), `src/feature/gc/collector_mark_sweep.zig` (walkRootsImpl /
  scanNativeStackRoots), `src/engine/codegen/shared/jit_abi.zig` (trampolines).
