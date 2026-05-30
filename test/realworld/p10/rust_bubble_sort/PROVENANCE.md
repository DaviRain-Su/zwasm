# Rust → wasm32 fixture: bubble sort (Phase 10 / realworld)

**Toolchain**: rustc 1.96.0 via nix `devShells.gen`
([`.dev/toolchain_provisioning.md`](../../../../.dev/toolchain_provisioning.md)).

- `sort.{rs,wasm,expect}` (cyc225) — `#![no_std]` bubble-sort of a local
  `[i32; 8]` (on the shadow stack), returning the 4th-smallest. `black_box` on
  the input forces the sort to run at runtime (no const-fold): the emitted wasm
  has nested loops + array `i32.load`/`i32.store` (swaps) + bounds-check
  `br_if` — a real algorithm exercising the shadow-stack path unlocked cyc224
  (`setupRuntime` global-init fix). input [5,2,8,1,9,3,7,4] → sorted
  [1,2,3,4,5,7,8,9]; a[3] = 4. wasmtime-confirmed.

**Build** (inside `nix develop .#gen`):
```sh
rustc --target wasm32-unknown-unknown -O --crate-type=cdylib -o sort.wasm sort.rs
```
**Result-check**: `run_edge_realworld_p10` → `runI32Export` `test` → `i32: 4`. ACTIVE.
