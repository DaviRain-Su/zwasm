# Dart toolchain fixtures (Phase 10 / GC + EH)

**Toolchain**: `dart compile wasm` (Dart 3.6+, when GC + EH support stabilises).

**Planned fixtures** (per design plan §4.3):
- `hello_world.dart.wasm` — basic `print('hello, world')` (GC heap entry path)
- `collection_ops.dart.wasm` — `List`/`Map` operations (struct + array.new + ref.test)
- `async_error.dart.wasm` — `async`/`await` with thrown exception (EH × Future)

**Build command (when impl ships)**:
```sh
dart compile wasm <src>.dart -o <name>.dart.wasm
```

**Status**: SKIP-P10-{GC,EH}-GAP until 10.G + 10.E impl rows land.
