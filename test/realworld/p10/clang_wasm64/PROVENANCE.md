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

**Status**: SKIP-P10-MEM64-GAP until 10.M impl row lands.
