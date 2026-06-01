# JIT result-bug: the stale-register / fresh-state confound

**Date**: 2026-06-02
**Context**: D-212 (gc/struct + gc/array f32 fields fail `ty=f32 got=0x69`
in the §1 JIT spec corpus, but every standalone repro returned the
*correct* value).

## Observation

A JIT codegen bug where a function result is **never written to its
return register** (here: an f32 from `struct.get` left in a GPR, the
f32-return reads stale V0/XMM0) is INVISIBLE to a naive standalone
repro. In a clean process the stale register happens to hold `0`, and
the corpus fixtures expected `0.0` (fields from `struct.new_default`),
so "reads stale reg" and "reads the real field" both yield `0.0` —
indistinguishable.

Wasted ~5 spike iterations chasing wrong hypotheses (GPR field store,
heap offset, cross-func ABI) because each fresh-heap/clean-register
repro returned the coincidentally-correct value.

## What broke the confound

1. **Compare the exact bytes**: fingerprint `cur_module_bytes` (fnv +
   len) — confirmed the failing module WAS `struct.7.wasm`, identical
   to my standalone copy. Same bytes, different result ⇒ the result
   depends on **ambient register/heap state**, not the module.
2. **Use a NON-ZERO expected value**: `struct.new (f32.const 2.5)` +
   cross-func `struct.get` → expect `2.5`. This fails in a clean
   process (the stale reg ≠ 2.5), making the bug deterministic and
   standalone-reproducible.

## Rules

- When a backend-comparison fail won't reproduce standalone, suspect a
  **register/memory-state dependence**: pick test inputs whose correct
  output is DISTINCT from the likely stale/uninitialized value (never
  0 / never the heap base).
- Fingerprint the in-context bytes before assuming you have the right
  module — `[gc/struct] get_0_0` matched a different mental model than
  the actual `cur_module_bytes`.
- The §1 assert-runner exe is NOT rebuilt by `zig build`; only by
  `zig build test-spec-wasm-3.0-assert`. A "stale exe" silently runs
  old code — verify with `strings <exe> | grep <probe>`.

Related: [[jit-passthrough-result-clobbered-by-call]] (same family:
result not in the expected register across a CALL boundary). D-212.
