# zwasm

A standalone WebAssembly runtime written in Zig. Runs Wasm modules as a CLI tool or embeds as a Zig library.

## Features

- **Full Wasm 3.0 support**: Core spec + all 9 ratified 3.0 proposals (GC, exception handling, tail calls, function references, multi-memory, memory64, branch hinting, extended const, relaxed SIMD), plus threads (79 atomics) and wide arithmetic
- **62,263 spec tests passing**: 100% on macOS ARM64 and Linux x86_64 (Windows x86_64 is also covered by CI)
- **4-tier execution**: Bytecode → predecoded IR → register IR → ARM64/x86_64 JIT (NEON/SSE SIMD), with HOT_THRESHOLD=3 for fast tier-up
- **WASI Preview 1 + Component Model**: 46/46 P1 syscalls, P2 via component-model adapter
- **Small footprint**: ~1.20 MB on Mac, ~1.56 MB on Linux (stripped, ReleaseSafe), ~3.5 MB runtime memory
- **Library and CLI**: use as a `zig build` dependency, link as a C shared library, or run modules from the command line
- **WAT support**: run `.wat` text format files directly

## Quick Start

```bash
# Run a WebAssembly module
zwasm hello.wasm

# Invoke a specific function
zwasm math.wasm --invoke add 2 3

# Run a WAT text file
zwasm program.wat
```

See [Getting Started](./getting-started.md) for installation instructions.
