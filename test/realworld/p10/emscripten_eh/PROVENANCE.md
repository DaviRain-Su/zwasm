# emscripten `-fwasm-exceptions` fixtures (Phase 10 / EH)

**Toolchain**: emscripten 3.x with `-fwasm-exceptions` flag —
the C++ Wasm 3.0 EH path (vs the legacy JS-throw path).

**Planned fixtures** (per design plan §4.3):
- `cxx_throw_catch.cpp.wasm` — basic `throw std::runtime_error`
  with matching `catch` handler (verifies try_table emit + FP-walk
  unwind per ADR-0114)
- `cxx_nested_try.cpp.wasm` — nested try_table; verifies tag
  identity via pointer equality (ADR-0114 D7)
- `cxx_uncaught.cpp.wasm` — `throw` with no matching catch
  → propagates to runtime abort (verifies EH × top-frame
  unwind invariant)

**Build command (when impl ships)**:
```sh
emcc -fwasm-exceptions <src>.cpp -o <name>.cpp.wasm
```

**Status**: SKIP-P10-EH-GAP until 10.E impl row lands.
