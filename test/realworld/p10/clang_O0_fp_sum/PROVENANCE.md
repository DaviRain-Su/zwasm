# clang `-O0` fixture: floating-point on the shadow stack (Phase 10 / realworld)

**Toolchain**: clang (`--target=wasm32`) via nix `devShells.gen`
(see [`.dev/toolchain_provisioning.md`](../../../../.dev/toolchain_provisioning.md)).

- `fp_sum.{c,wasm,expect}` (cyc227) — a C `int test()` that sums a local
  `double a[4]` then multiplies + truncates to int, compiled `-O0`. Exercises
  the floating-point codegen cell: `f64.load`/`f64.add`/`f64.mul` (the array +
  accumulator live on the shadow stack) + `i32.trunc_f64_s`. Completes the
  real-toolchain matrix (rust/clang × control-flow/memory/algorithm/FP/shadow-
  stack). a=[1.5,2.5,3.0,4.0] → sum 11.0 × 7.0 = 77.0 → (int) 77. wasmtime-confirmed.

## Build (inside `nix develop .#gen`)
```sh
clang --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--export-all -O0 \
    -o fp_sum.wasm fp_sum.c
```
**Result-check**: `run_edge_realworld_p10` → `runI32Export` `test` → `i32: 77`. ACTIVE.
