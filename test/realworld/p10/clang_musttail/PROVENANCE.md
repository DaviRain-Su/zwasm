# clang `__attribute__((musttail))` fixtures (Phase 10 / TC)

**Toolchain**: clang 21 with `__attribute__((musttail))` — the C
surface for proper tail calls (lowers to Wasm 3.0 `return_call`).

## Landed fixtures

- `musttail_sum.{c,wasm,expect}` — a `noinline` self-recursive
  `sum_tail(n, acc)` (the `noinline` keeps clang -O2 IPSCCP from
  constant-evaluating the recursion, so a real `return_call` survives
  in the binary). Exported `test()` tail-calls `sum_tail(5, 0)` →
  `return_call`, summing 5+4+3+2+1 = 15. Result-checked through the
  JIT (`runI32Export` via the edge-case runner; `.expect` = `i32: 15`).
  Exercises `return_call` WITH args + frame reuse end-to-end (D-205).

## Build recipe (nix-wrapped toolchain; per lesson 2026-05-30-clang-wasm-realworld-toolchain-recipe)

```sh
WASMLD=$(ls -d /nix/store/*lld*/bin | head -1)   # provides wasm-ld
PATH="$WASMLD:$PATH" NIX_HARDENING_ENABLE="" clang --target=wasm32 \
    -nostdlib -Wl,--no-entry -Wl,--export-all -O2 -mtail-call \
    -o musttail_sum.wasm musttail_sum.c
```

- `NIX_HARDENING_ENABLE=""` drops the injected `-fzero-call-used-regs`
  (unsupported on wasm32). `-O2` keeps simple funcs in wasm-locals
  (no shadow-stack spill → `runI32Export`'s instantiation suffices).

The `musttail` attribute makes the tail-call disposition a hard
compile-time requirement. Verifies ADR-0112 D6 (safepoint-free
invariant) + the JIT `return_call` codegen (10.TC-JIT) end-to-end.

## Result-check harness

`zig build test-edge-cases` / `test-all` walks `test/realworld/p10/**`
via the JIT edge-runner (`run_edge_realworld_p10` step in `build.zig`),
running each `.wasm` with a sibling `.expect` through `runI32Export`.

**Status**: ACTIVE — `musttail_sum` result-checked green (10.TC-JIT IT-5,
cyc201). Further fixtures (CPS continuation, wasm64) as their gaps close.
