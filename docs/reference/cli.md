# CLI reference

The `zwasm` binary is deliberately minimal — `run` + `compile`, the
wasmtime/wazero-aligned shape for a runtime (ADR-0159). Validation is
programmatic (C-API `wasm_module_validate` / Zig `Engine.compile`);
wat↔wasm conversion and module introspection are `wasm-tools` / `wabt`'s
job, not a runtime's. Dispatch source:
[`src/cli/main.zig`](../../src/cli/main.zig).

## Commands

```
zwasm                                     # version + build-options banner
zwasm run <file.wasm|.cwasm> [args...]    # run a module
zwasm compile <file.wasm> -o <out.cwasm>  # compile to a .cwasm AOT artifact
zwasm --version | -V                      # version
zwasm --help | -h | help                  # usage
```

An unrecognised first token is an error (exit 2) — the surface is
explicit; there is no bare-file shortcut.

### `run`

Drives a WASI module's `_start` / `main` and exits with the guest's
`proc_exit` code. A `.cwasm` (CWAS magic) loads + runs directly (no
parse/compile).

| Flag                     | Effect                                                                                                |
|--------------------------|-------------------------------------------------------------------------------------------------------|
| `--invoke <name>`        | run the named export instead of `_start`/`main` (zero-arg; result surfaces as the exit code — D-273) |
| `--engine <interp\|jit>` | `interp` (default, full WASI) or `jit` (compute-only — SIMD/compute, no WASI I/O)                    |
| `--dir <host>[:<guest>]` | preopen a host directory for WASI (colon separator; guest path mirrors host when omitted)             |

### `compile`

Reads a `.wasm`, runs the JIT pipeline, and writes a `.cwasm` v0.1 AOT
artifact (ADR-0039) to the `-o` / `--output` path. `zwasm run
<file.cwasm>` executes it.

## Engine selection

- `.cwasm` input → AOT-loaded directly.
- `.wasm` input → interpreter by default; `--engine jit` opts into the
  compute-only JIT.

## Environment

- `ZWASM_DEBUG=<categories>` — `dbg.zig` category filter.
- `ZWASM_DIAG=<channels>` — diagnostic trace ringbuffer drain.

## Not shipped

`validate` / `inspect` / `features` / `wat` / `wasm` are deliberately
absent (ADR-0159). wasmtime-style `--env` / `--fuel` / `--timeout` and
`--invoke NAME=ARGS` arg-marshalling + typed-result printing are tracked
as D-273.
