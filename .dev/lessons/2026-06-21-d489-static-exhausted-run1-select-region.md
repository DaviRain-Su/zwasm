# D-489 step 6: static analysis exhausted; localized to run$1's nested-select gate region

**Date**: 2026-06-21
**Method**: forked subagent disassembled IsNil(65)+run$1(136) x86_64-vs-arm64 (llvm-mc);
main thread read run$1's WASM at the bail region.

## Findings

- **IsNil(65) is CLEAN** (fork, static): call-level control flow matches arm64 (3 calls);
  spill slots -72/-88/-104(%rbp) are store-then-reload-same-value with NO aliasing (not a
  D-490-class bug); globals-base reload-from-[R15+48]-before-each-access is correct. IsNil
  is the gateway (called 1×), not the miscompile.
- **run$1(136)** is an **8253-instruction** coroutine-transformed function — NOT statically
  tractable by asm-eyeball. The divergence is a **taken-vs-not-taken branch**, not a
  corrupted memory value.
- **Exact bail region pinned** (run$1 WASM lines 1539-1551): a **nested scalar `select`**
  computing the `if` that gates the encode path:
  `select(global.get 1, local 1, (local1&1)==0)` → `local.tee 1` →
  `select(global.get 1, 1, local1)` → `if` (→ reflectValue). Plus coroutine REWIND br_ifs
  (`global.get 1; i32.const 1; i32.eq; br_if @1`). global 1 = TinyGo task state, global 2 =
  shadow-stack ptr.
- **`emitSelectCtx` (op_alu_int.zig:1093) inspected = structurally correct**: cond/val1/result
  use spill-stage 0 (R10), val2 stage 1 (R11); cond is dead after `TEST` and MOV/loads don't
  clobber flags, so reusing R10 for val1/result is safe across all spill combos I traced.
  So `select` is probably NOT the bug either — leaving **global.get 1** codegen or the
  **br_if** (rewind-check) condition under deep spill as the remaining suspects.

## Conclusion + next step (step 7)

Static + profiling methods are EXHAUSTED. 3 synthetic fixtures (spilled load/store/select) +
mv2 all failed to reproduce — the bug is bound to run$1's real deep frame. The definitive
pinpoint needs **instruction-level dynamic value tracing for func 136 only** (interp=correct
vs x86_64-jit=wrong) at the 1539-1551 region: dump each ZIR op's operand-stack values; the
first divergent value is the bug. Extend `call_profile`/the interp dispatch to a per-op value
dump gated for func 136; for the JIT, emit a per-op value-store (heavy — or use gdb on ubuntu
native x86_64). Reusable `jit.callcount`/`jit.calledge` profilers got us from 1MB→1 region.
