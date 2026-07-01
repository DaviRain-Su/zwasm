# Spec-corpus JIT skips: weight by ROOT CAUSE, not by dispatch-shape tally

2026-06-02. After 2-arg JIT dispatch (D-217) took jit pass 127→260, the next
chunk was picked by tallying eligibility-skip messages (`args=N results=M`):
3-arg showed ~16 cases, so 3-arg dispatch looked like a ~16-flip win.

It flipped **1** (skip→fail), pass unchanged. The 3-arg cases live in modules
that **fail to JIT-compile** (unemitted gc ops), so the per-assert eligibility
gate never even runs — the module-level `cur_jit == null` short-circuit skips
all its asserts regardless of dispatch arity.

## The real skip taxonomy (skip=1024)

- **~915 module-compile-rejects** — the whole module fails `JitInstance.init`
  (compileWasm/setupRuntime): multi-memory (`MultipleMemories`, ~407), unemitted
  ops (br_on_null / return_call_indirect / gc ops), validate/const-expr gaps.
  These are SILENT in `--fail-detail` (the null-`cur_jit` skip path prints
  nothing). Only ~109 eligibility-skips print.
- **~109 eligibility-shape skips** — non-scalar (v128 / ref) args+results,
  multi-value (results≥2), 3-arg, cross-module. THESE are what the
  `args=/results=` tally counts — a small minority.

## Takeaways

- A dispatch-arity chunk yields ~0 corpus pass until the underlying modules
  COMPILE. Order the work by what unblocks the most asserts: **module-compile
  coverage (op emit) > shape dispatch**. The biggest module-reject cluster is
  multi-memory (407, likely Phase-14 deferred), then gc unemitted ops.
- The `--fail-detail` skip tally is biased: it under-counts the dominant
  (module-reject) class because that skip path doesn't print. Tally skips by
  measuring `cur_jit == null` vs eligibility separately, OR count compile
  rejects at the `.module` arm. Don't infer the lever from the printed subset.
- This is the same shape as `2026-06-02-spec-jit-single-arg-reopens-state-bridge`:
  measure the FULL taxonomy (here: include the silent class) before picking the
  mechanism. A printed-subset tally is not the population.
- The 3-arg dispatch still landed (correct, completes scalar 0..3) — future
  gc-op fixes dispatch those cases immediately. Not wasted, just not the lever.
