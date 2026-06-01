# Late §10 JIT-corpus completion is per-module blocker STACKS, not op-type gaps

2026-06-02. After memory64 hit 100% JIT-green (+208 corpus, the data-offset fix),
a long run of gc/funcref fixes each landed CORRECT but flipped **~0 corpus**:
single-arg/2-arg/3-arg dispatch, gc ref.i31 globals (+16, the last mover),
ref.as_non_null liveness, ref-branch liveness, supertypes→validator, i31 table
elem-init. All real parity gaps; all ~0 net corpus.

## Why: each remaining module has a STACK of 3-6 distinct blockers

The JIT compile path rejects a module at the FIRST gap (`JITmodrej`). Clearing
that gap just surfaces the next. Worked example — `gc/i31.1.wasm` (table-of-i31ref):
1. InvalidGlobalInitExpr (ref.i31 global) → fixed D-220.
2. StackTypeMismatch (concrete subtyping) → fixed D-220 supertypes.
3. **InvalidFuncIndex** (current reject — table.init/elem funcidx check).
4. i31ref table elem-init not applied → fixed D-221 (but UNREACHED: blocker #3
   rejects before setup runs).
5. table.grow/fill/copy on i31ref tables (unemitted) — not yet hit.
A module flips only when its LAST blocker clears; fixing gap #4 while #3 rejects
yields 0. memory64 was the exception (most modules shared the SINGLE offset gap).

## Takeaways

- Op-type / gap-type grinding ACROSS modules is the wrong shape for late-phase
  corpus completion — it pays 0 until the per-module tail clears. Measure by
  MODULE blocker-depth, not by aggregate gap counts.
- Two higher-yield shapes: **(a)** pick ONE module, enumerate its FULL stack
  (`JITmodrej` repeatedly as each clears), clear ALL in a focused multi-fix push
  → that module flips (real corpus win). **(b)** target **fails on COMPILING
  modules** (executed-and-wrong) — those already run, so a fix is a direct
  fail→pass flip, no stack to clear first.
- The incremental fixes are NOT wasted (each is a real parity gap removed +
  necessary for the eventual flip) — but the per-turn corpus signal goes quiet,
  so judge progress by `JITmodrej`-cause reduction + fail-count, not pass-count.
- Honest scoping: §10 both-backends-100% is a deep multi-cycle tail here; the
  diagnostics (`JITmodrej`) + this map make the remaining work tractable but it
  is genuinely many focused chunks, not a few big levers (those are spent).
