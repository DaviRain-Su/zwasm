# `wasi_p2_hello_rust.wasm` — real Rust Component-Model fixture (Phase E2)

The Phase E2 "CM actually works, real toolchain" existence proof: a genuine
`rustc --target wasm32-wasip2` component (NOT hand-authored) that runs end-to-end
through zwasm's general instance-graph engine (ADR-0175) and prints to stdout.

Unlike the hand-authored `wasi_p2_*` fixtures, this exercises the full real-world
shape: wit-bindgen's **shim / fixup-table indirection** (memory-needing host
lowers reached via `call_indirect` through a fixup-filled table — the D-310
runtime fix), the complete `wasi:cli/run` world (environment / terminal / io
/ exit / clocks / random / filesystem / poll), and real WASI types.

## Source

`wasi_p2_hello_rust.rs` — a one-line `fn main() { println!(...) }`.

## Build (Mac gen host only)

```sh
nix develop .#gen --command bash -c '
  rustc --target wasm32-wasip2 -O wasi_p2_hello_rust.rs -o /tmp/hello.wasm
  wasm-tools strip /tmp/hello.wasm -o wasi_p2_hello_rust.wasm   # 2.4 MB → ~78 KB
  wasm-tools validate --features component-model wasi_p2_hello_rust.wasm'
```

The committed `.wasm` is stripped (names/debug sections removed); it still runs.
Asserted in `src/api/component.zig` ("E2 (bundle exit)") and dogfooded via
`zwasm run test/component/wasi_p2_hello_rust.wasm`.
