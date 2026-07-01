# clang `-O0` fixture: shadow-stack array sum (Phase 10 / realworld)

**Toolchain**: clang (`--target=wasm32`) via nix `devShells.gen`
(see [`.dev/toolchain_provisioning.md`](../../../../.dev/toolchain_provisioning.md)).

- `arr_sum.{c,wasm,expect}` (cyc226) — a C `int test()` summing a local
  `int a[8]` at **`-O0`** → clang spills the array + loop vars to the shadow
  stack (`__stack_pointer`). This is the HEAVIEST shadow-stack test (no regalloc)
  and a different toolchain than the rust fixtures. Validates the cyc224
  `setupRuntime` global-init fix for clang `-O0` (the clang-recipe lesson's
  "`-O0` traps" claim is now lifted). `-O0` also avoids the `-O2` const-fold,
  so no `black_box` trick is needed. 5+2+8+1+9+3+7+4 = 39. wasmtime-confirmed.

## Build (inside `nix develop .#gen`)
```sh
clang --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--export-all -O0 \
    -o arr_sum.wasm arr_sum.c
```
**Result-check**: `run_edge_realworld_p10` → `runI32Export` `test` → `i32: 39`. ACTIVE.
