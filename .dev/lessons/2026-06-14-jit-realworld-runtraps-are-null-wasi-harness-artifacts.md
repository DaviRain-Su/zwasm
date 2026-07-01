# JIT realworld "RUN-TRAP" were null-WASI-host harness artifacts, not JIT miscompiles

**Date**: 2026-06-14 · **Context**: Phase B / D-283 first triage — the realworld
corpus under `ZWASM_JIT_RUN=1` reported "35 pass / 12 RUN-TRAP / 9 COMPILE-OP",
and the plan assumed RUN-TRAP = "interp-passes ⇒ JIT miscompile/WASI-gap".

## Observation

The 12 RUN-TRAP are **not** JIT miscompiles. `test/realworld/run_runner_jit.zig`
runs the JIT-compiled `_start` via `engine.runner.runVoidExport`, which forwards
to `runVoidExportWasi(.., wasi_host = NULL, ..)` — it executes the program with
**no WASI host wired**. Any fixture that reaches a WASI import call (`fd_write`
from printf, `proc_exit` from a WASI command's `_start` epilogue) mid-execution
therefore traps. That trap is the harness's, not the JIT's.

Proof: the WASI-aware CLI path `zwasm run --engine jit <fixture>` (`runWasmJit`,
which wires a real WASI host) runs both `emcc_primes` and `tinygo_sort` (sampled
from the trap set) **correctly** — right stdout, exit 0 — consistently (3/3). The
JIT compiles AND executes them fine. The "35 pass" are just fixtures that return
from `_start` before touching WASI; the run-stage measure was never representative.

## Rule

1. **A JIT "run" harness that measures correctness MUST wire a WASI host** (or
   diff stdout vs a reference), exactly like the interp `diff_runner` does. A
   bare `runVoidExport` (null host) only answers "did `_start` trap without a
   host", which is trivially yes for any WASI program — a useless signal that
   reads as a JIT bug.
2. **Before triaging a batch of "JIT traps" as miscompiles, reproduce ONE on the
   real CLI path** (`--engine jit`, WASI-aware). If the CLI runs it correctly,
   the trap is a harness artifact — fix the harness, not the compiler.
3. The real JIT-correctness net for the realworld corpus is a **`--jit` lane in
   `diff_runner.zig`** (mirror the `--aot`/`--wasmer` lanes): run via the
   WASI-aware JIT path, byte-diff stdout vs wasmtime. (D-283 discharge.)
4. Distinct + still-real: the 9 `go_*` COMPILE-OP (`UnsupportedOp`) are genuine
   unimplemented-JIT-op gaps — they fail at compile, before any run/host concern.
