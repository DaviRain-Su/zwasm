# clang `--target=wasm64` + emscripten `-sMEMORY64=1` fixtures (Phase 10 / memory64)

**Toolchain**: clang 19+ + emcc 3.x with `-sMEMORY64=1` —
the only realworld toolchain emitting Wasm 3.0 memory64 code.

**Planned fixtures** (per design plan §4.3):
- `big_alloc.c.wasm` — `malloc(5LL * 1024 * 1024 * 1024)`
  (> 4 GiB; verifies memory64 mmap + i64 offset materialise
  per ADR-0111 D5)
- `big_memcpy.c.wasm` — `memcpy(dst, src, 5LL * 1024 * 1024 * 1024)`
  (verifies bulk-memory bounds-check at 64-bit width)

**Build command (when impl ships)**:
```sh
emcc -sMEMORY64=1 <src>.c -o <name>.c.wasm
```

**Host requirement**: 64-bit host (no Win64-only restriction; both
arm64 + x86_64 work — the runtime mmap call returns a single
contiguous region per Memory).

**Status** (2026-05-26 update): the 10.M impl row interp + codegen
+ SIMD memarg are SHIPPED — memory64 paths are fully exercised by
`test/edge_cases/p10/memory64/` (3 fixtures: page-edge load,
bounds trap, store-load round-trip via i64 addr) and the
`test/spec/wasm-3.0-assert/memory64/` smoke corpus (6 manifests,
337 assert_return + 205 assert_trap directives baked from upstream
spec testsuite). The remaining gap for *this* directory's
realworld fixtures is **toolchain-side**, not impl-side:

- Needs `emcc -sMEMORY64=1` (emscripten 3.x) on the build host
  to compile `big_alloc.c` / `big_memcpy.c` into Wasm binaries.
- Needs a 64-bit test host (Mac aarch64 + Linux x86_64 qualify;
  Win64 also OK per ADR-0111 D5 — `MapViewOfFile3` for >4 GiB).

Once the build host has the toolchain set up (or pre-built
artifacts are sourced from upstream emscripten test suites),
drop the `big_alloc.c.wasm` + `big_memcpy.c.wasm` + matching
`.expect` files here. The `test/realworld/runner.zig` already
walks this directory; the fixtures will execute on landing.

Skip token retired from impl-driven to toolchain-driven:
**`SKIP-P10-MEM64-REALWORLD-TOOLCHAIN`** — emcc not in PATH or
not configured with `-sMEMORY64=1` support. The original
`SKIP-P10-MEM64-GAP` (impl-driven) is dissolved by this update.
