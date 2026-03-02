# Build Configuration

zwasm builds all features by default. For size-constrained environments — embedded systems, edge functions, minimal containers — you can strip features you do not need at compile time.

## Feature flags

Pass flags to `zig build` to enable or disable features:

| Flag | Description | Default |
|------|-------------|---------|
| `-Djit=false` | Disable JIT compiler (ARM64/x86_64). Interpreter only. | `true` |
| `-Dcomponent=false` | Disable Component Model (WIT, Canon ABI, WASI P2). | `true` |
| `-Dwat=false` | Disable WAT text format parser. Binary-only loading. | `true` |
| `-Dsimd=false` | Disable SIMD opcodes (v128 operations). | `true` |
| `-Dgc=false` | Disable GC proposal (struct/array types). | `true` |
| `-Dthreads=false` | Disable threads and atomics. | `true` |

Example:

```bash
zig build -Doptimize=ReleaseSafe -Djit=false -Dwat=false
```

## Size impact

Measured on Linux x86_64, ReleaseSafe, stripped:

| Variant | Flags | Size (approx.) | Delta |
|---------|-------|---------------:|------:|
| Full (default) | (none) | ~1.23 MB | — |
| No JIT | `-Djit=false` | ~1.03 MB | −16% |
| No Component Model | `-Dcomponent=false` | ~1.13 MB | −8% |
| No WAT | `-Dwat=false` | ~1.15 MB | −6% |
| Minimal | `-Djit=false -Dcomponent=false -Dwat=false` | ~940 KB | −24% |

The minimal configuration still passes all non-JIT spec tests and supports the full Wasm 3.0 instruction set (interpreted).

## Common profiles

### Interpreter-only

Smallest binary. Suitable when startup latency matters more than peak throughput:

```bash
zig build -Doptimize=ReleaseSafe -Djit=false
```

### Minimal CLI

Strip everything not needed for running core Wasm binaries:

```bash
zig build -Doptimize=ReleaseSafe -Djit=false -Dcomponent=false -Dwat=false
```

### Full (default)

All features enabled. Recommended for general use:

```bash
zig build -Doptimize=ReleaseSafe
```

## How it works

Feature flags are defined in `build.zig` as `b.option(bool, ...)` values, then passed to the Zig module as compile-time options. Source files check them with `@import("build_options")`:

```zig
const build_options = @import("build_options");

if (build_options.enable_jit) {
    // JIT compilation path
} else {
    // Interpreter-only path
}
```

When a feature is disabled, Zig's dead code elimination removes all related code from the binary. There is no runtime overhead — disabled features simply do not exist in the output.

## Library builds with flags

Feature flags work with the library target too:

```bash
# Build a minimal shared library (no JIT, no component model)
zig build lib -Doptimize=ReleaseSafe -Djit=false -Dcomponent=false
```

The resulting `libzwasm.so` / `.dylib` will be smaller but still expose the full C API. Functions that depend on disabled features will return an error when called (e.g., loading a component binary with `-Dcomponent=false` returns an error via `zwasm_last_error_message()`).

## CI size matrix

The CI pipeline includes a `size-matrix` job that builds five variants (full, no-jit, no-component, no-wat, minimal) and reports their stripped sizes. This catches unexpected size regressions when new code is added.

See `.github/workflows/ci.yml` for the full configuration.
