# JIT-vs-wasmtime differential is wrapper_thunk-blocked for smith corpora

**Date**: 2026-06-20 · **Refs**: ADR-0106 (wrapper_thunk),
`scripts/fuzz_wasmtime_diff.py`, `test/fuzz/fuzz_exec.zig`

## Why this was attempted

exec-fuzz (interp-vs-JIT) uses the interp as oracle, but the interp is NON-SIMD
(JIT-only SIMD by design). So JIT SIMD codegen has NO in-tree differential
oracle. wasmtime has SIMD → a zwasm-JIT-vs-wasmtime differential could catch JIT
SIMD miscompiles the spec corpus misses.

## What happened

Built the differential (`scripts/fuzz_wasmtime_diff.py`) — proven on the curated
`exec_seed` corpus (compared=6, 0 mismatch). But on a `wasm-tools smith` SIMD
corpus it reports **compared=0**: every module fails with `compileWasm: func[N]
→ UnsupportedOp`. Root cause: `compileWasm` compiles the WHOLE module, and the
host-invoke `wrapper_thunk` (ADR-0106) only supports a SUBSET of signatures
(0/1/3-param; results all-GPR or all-XMM). A smith module almost always has ≥1
function with an unsupported sig (f32/v128 result, 2/4+ params) → the whole
module won't compile → NO export is `--invoke`-able, even wrapper-friendly ones.

## The load-bearing conclusions

1. **JIT SIMD body codegen is CORRECT** — verified independently: a 0-param
   i32-result func chaining f64x2.nearest / i8x16.narrow / i16x8.extend_high /
   f32x4.convert_i32x4_s / i32x4.extract_lane JIT-runs and matches wasmtime;
   plus simd_assert 25075/0. The differential's 800 "TRAP-DIVERGE" hits were ALL
   the wrapper UnsupportedOp (now skipped by the tool), not miscompiles.
2. **`UnsupportedOp` lives ONLY in `wrapper_thunk.zig`** — if you see it from
   compileWasm, it is a host-invoke SIGNATURE limitation, never a body-codegen
   gap (those raise other errors). Grep confirms it.
3. **To make wasmtime-vs-JIT differential productive**: either broaden
   wrapper_thunk to more sigs (ADR-0106 follow-on — host-boundary, not guest
   execution, so low correctness urgency), or hand-curate wrapper-friendly
   modules. Raw smith won't work as-is. The tool is committed for the curated
   path + future use.
