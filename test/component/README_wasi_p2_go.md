# p17 E2 fixtures: tinygo wasm32-wasip2 components (Go cross-toolchain proof)

Two real `tinygo build -target=wasip2` components — the second Phase-E2
cross-toolchain existence proof beside Rust (`wasi_p2_hello_rust.wasm`).

- `wasi_p2_hello_go.wasm` — `fmt.Println("hello")` (source: the pre-existing
  `wasi_p2_hello.go`). Full `wasi:cli` world + filesystem/random/clocks
  interfaces; wit-component start-shim calls `$main`'s `_initialize` as an
  IMPORTED start function (the host_calls start-dispatch fix this fixture
  landed with).
- `wasi_p2_fs_go.wasm` — `wasi_p2_fs_go.go`: mkdir → WriteFile → Stat →
  Rename → ReadDir (directory-entry-stream) → Remove ×2 under a `/work`
  preopen, asserting each step; prints `FS-OK b.txt`. Exercises the
  path-addressed descriptor trampolines (`*-at` family) end-to-end.

## Reproduce (Mac gen shell)

```sh
nix develop .#gen
mkdir /tmp/build && cd /tmp/build
cp <repo>/test/component/wasi_p2_hello.go main.go     # or wasi_p2_fs_go.go
printf 'module m\n\ngo 1.25\n' > go.mod   # PIN 1.25: tinygo 0.40.1 rejects the shell's go1.26 directive
tinygo build -target=wasip2 -o out.wasm .
wasm-tools strip out.wasm -o stripped.wasm            # ~730 KB -> ~320 KB
wasmtime run stripped.wasm                            # cross-check
zwasm run stripped.wasm                               # (fs: --dir <host>:/work)
```

Toolchain: tinygo 0.40.1 (gen shell, `flake.nix`) builds wasip2 components
natively — no wit-bindgen-go / cargo-component / adapter needed for the
`wasi:cli/run` world.
