# Migrating from zwasm v1 to v2

zwasm v2 is a ground-up redesign of the runtime. **The v1 ABI is
intentionally dropped** — v2 does not aim for source- or binary-compatibility
with v1. This guide maps every v1 consumer surface to its v2 replacement so an
existing embedder can port forward.

> Why a clean break? v2 ships the same capabilities as v1 (see the parity table
> below) on a redesigned single-pass architecture, and standardises the C API on
> the upstream [wasm-c-api](https://github.com/WebAssembly/wasm-c-api) so zwasm
> is a drop-in for hosts already targeting that interface. A compatibility shim
> would have re-imported v1's implicit-contract sprawl; the redesign was the
> point.

## What stays the same (v1 → v2 parity)

| Capability                | v1                | v2 v0.1.0 |
|---------------------------|-------------------|-----------|
| Wasm 3.0 (9 proposals)    | Complete          | Complete  |
| Wide arithmetic           | Complete          | Complete  |
| Custom page sizes         | Complete          | Complete  |
| WASI 0.1 (preview1)       | Complete          | Complete  |
| JIT platforms             | aarch64-darwin / aarch64-linux / x86_64-linux / x86_64-windows | Same |
| Spec testsuite            | 100%, 0 skip      | 100%, 0 skip |
| Binary footprint          | 1.2–1.6 MB stripped | Comparable |

The **observable Wasm semantics are unchanged** — a module that ran correctly
on v1 produces the same results on v2. What changed is the *host-facing API*.

---

## 1. Zig embedding API — the biggest change

v1 exposed a single monolithic `WasmModule` that fused load, instantiation, and
invocation. v2 separates the lifecycle into **`Engine` → `Module` → `Instance`**
(compile once, instantiate many), adds a comptime-typed call wrapper
(`TypedFunc`), and makes host imports / WASI first-class via a `Linker`.

### Happy path

**v1:**

```zig
const zwasm = @import("zwasm");

var module = try zwasm.WasmModule.load(allocator, wasm_bytes);
defer module.deinit();

var args = [_]u64{ 10, 20 };
var results = [_]u64{0};
try module.invoke("add", &args, &results);
// results[0] == 30
```

**v2:**

```zig
const zwasm = @import("zwasm");

var eng = try zwasm.Engine.init(allocator, .{});
defer eng.deinit();

var module = try eng.compile(wasm_bytes); // parse + validate, immutable + reusable
defer module.deinit();

var instance = try module.instantiate(.{});
defer instance.deinit();

// Untyped: values flow through the tagged zwasm.Value union.
var args = [_]zwasm.Value{ .{ .i32 = 10 }, .{ .i32 = 20 } };
var results = [_]zwasm.Value{.{ .i32 = 0 }};
try instance.invoke("add", &args, &results);
// results[0].i32 == 30

// Typed (ergonomic): comptime-checked signature.
const add = instance.typedFunc(fn (i32, i32) i32, "add");
const sum = try add.call(.{ 10, 20 }); // sum == 30
```

### Type & call mapping

| v1                                       | v2                                                            |
|------------------------------------------|---------------------------------------------------------------|
| `zwasm.WasmModule`                       | split into `zwasm.Engine` / `zwasm.Module` / `zwasm.Instance` |
| `WasmModule.load(alloc, bytes)`          | `Engine.init(alloc, .{})` then `engine.compile(bytes)`        |
| (load == instantiate)                    | `module.instantiate(.{})` — separate step; one `Module` → many `Instance`s |
| `module.invoke(name, &[]u64, &[]u64)`    | `instance.invoke(name, &[]Value, &[]Value)` (untyped) — raw `u64` slots become the tagged `zwasm.Value` union |
| (no typed call)                          | `instance.typedFunc(fn(P...) R, name).call(.{...})` (comptime-checked) |
| linear memory via internal accessors     | `instance.memory()` → `zwasm.Memory` with `.read(T, addr)` / `.write(addr, v)` / `.size()` |

### Errors

v1 returned a coarse error and exposed a thread-local last-error string. v2's
`Instance.invoke` returns a Zig error set carrying every Wasm trap as a named
variant — `error.DivByZero`, `error.Unreachable`, `error.IntOverflow`,
`error.OutOfBoundsLoad` / `...Store` / `...TableAccess`,
`error.InvalidConversionToInt`, `error.UninitializedElement`,
`error.IndirectCallTypeMismatch`, `error.StackOverflow`,
`error.CallStackExhausted`, `error.OutOfMemory`. Compile-time errors are
distinguished too: `error.ParseFailed` (malformed bytes) vs
`error.ValidateFailed` (structurally valid but ill-typed).

```zig
instance.invoke("div", &args, &results) catch |err| switch (err) {
    error.DivByZero => { ... },
    error.Unreachable => { ... },
    else => return err,
};
```

### Host imports and WASI — now first-class via `Linker`

v1 bolted imports onto load (`loadWithImports`) and WASI onto a separate
constructor (`loadWasi`). v2 routes both through a `Linker`:

```zig
fn hostAdd(_: *zwasm.Caller, a: i32, b: i32) i32 {
    return a +% b;
}

var lk = zwasm.Linker.init(&eng);
defer lk.deinit();
try lk.defineFunc("env", "add", fn (*zwasm.Caller, i32, i32) i32, hostAdd);
try lk.defineWasi(.{});                 // wire WASI preview1
// try lk.defineMemory("env", "shared", some_memory); // cross-instance sharing

var instance = try lk.instantiate(&module);
defer instance.deinit();
```

A host function receives a `*zwasm.Caller`; `caller.memory()` reaches the
instance's linear memory. A signature mismatch between the module's declared
import type and the registered function is caught at instantiation
(`error.SignatureMismatch`).

### Allocator ownership (unchanged in spirit)

As in v1, the caller's allocator propagates to all internal allocations and
must outlive the objects. v2 keeps the strict-pass discipline: every internal
allocation goes through the allocator you hand to `Engine.init`.

---

## 2. C API — now standard wasm-c-api

v1 shipped a single custom header (`zwasm.h`) with `zwasm_*` opaque types and a
`uint64_t[]` value convention. v2's primary C ABI is the **upstream wasm-c-api
standard** (`wasm.h`), so a host already written against wasmtime/wasmer's
`wasm_*` interface can relink against zwasm.

| v1                                  | v2                                                       |
|-------------------------------------|----------------------------------------------------------|
| `include/zwasm.h` (custom, only)    | `include/wasm.h` — upstream wasm-c-api standard (primary) |
| —                                   | `include/wasi.h` — host-side WASI extension (`zwasm_wasi_*`) |
| custom `zwasm.h` types/functions    | `include/zwasm.h` — small zwasm-specific extensions, subordinate to `wasm.h` |
| `zwasm_module_t`, `zwasm_config_t`, … | wasm-c-api `wasm_engine_t`, `wasm_store_t`, `wasm_module_t`, `wasm_instance_t`, `wasm_func_t`, … |
| `uint64_t[]` args/results           | wasm-c-api `wasm_val_t` / `wasm_val_vec_t`               |
| `zwasm_last_error_message()`        | wasm-c-api `wasm_trap_t` (returned from calls)           |

Port your C host to the wasm-c-api shapes (`wasm_engine_new` →
`wasm_store_new` → `wasm_module_new` → `wasm_instance_new` →
`wasm_func_call`). The header is vendored read-only at a pinned upstream commit;
WASI host configuration lives in `wasi.h`.

---

## 3. CLI

The v2 CLI at v0.1.0 is intentionally minimal — the embedding APIs (Zig / C)
are the primary surface, and capability configuration lives there.

**v2 commands:**

```
zwasm                                                  # print version + build options
zwasm run [--invoke <name>] [--engine <interp|jit>] [--dir <host>[:<guest>]] <file.wasm|file.cwasm> [args...]
zwasm compile <file.wasm> -o <out.cwasm>               # ahead-of-time compile
```

Key deltas from v1's CLI:

- **`run` is explicit** — `zwasm run module.wasm` (v1 accepted a bare path). The
  trailing arguments after the `.wasm` path are the WASI guest's `argv`.
- **`--engine <interp|jit>`** selects the engine. The **default is `interp`**
  (full WASI). `--engine=jit` is **compute-only** (see §4); it rejects `--dir`.
  (v1 defaulted to JIT.)
- **`--dir <host>[:<guest>]`** preopens a directory for WASI (as in v1).
- **`compile` + `.cwasm`** — ahead-of-time compilation is new in v2. A `.cwasm`
  artifact is auto-detected by `run` and executes without re-parsing.
- v1's richer capability flags (`--allow-read/write/env/path`, `--sandbox`,
  `--env`, `--fuel`, `--max-memory`, `--batch`, `--link`) and the
  `validate`/`inspect`/`features`/`wat`/`wasm` subcommands are **not yet on the
  v2 CLI**; they are scheduled for later phases. For fine-grained capability and
  resource control today, embed via the Zig or C API.

---

## 4. WASI

WASI **0.1 (preview1)** support matches v1 — under the **interpreter** (the
default engine), the full WASI surface is available. The capability model is
deny-by-default.

**New caveat:** the **JIT engine is compute-only**. `--engine=jit` (and the
JIT execution path in the embedding API) executes pure computation (including
SIMD) but does **not** perform WASI I/O yet — `fd_write` does not reach stdout,
`proc_exit` does not carry an exit code, and `--dir` is rejected on the JIT
path. Run WASI programs on the default interpreter; use the JIT for
compute/embedding workloads. WASI 0.2 (preview2, Component Model) is a
post-v0.1.0 item.

---

## Reference

- Zig embedding API: `docs/zig_api_design.md` and the worked examples in
  `examples/zig_host/`.
- C API: the vendored `include/wasm.h` (wasm-c-api) + `include/wasi.h`.
- Capability/parity rationale: ROADMAP §1.1 (ABI drop), §1.2 (parity line),
  §3.2 (scope), §10 (consumer surfaces).
