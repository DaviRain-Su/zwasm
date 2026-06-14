# Zig embedding API reference

The native Zig facade (ADR-0109) lives in
[`src/zwasm.zig`](../../src/zwasm.zig) and `src/zwasm/`. It is the
authoritative source — this page organizes the surface and links to it;
exact signatures + doc-comments live in the code. Runnable usage:
[`examples/zig_dep/`](../../examples/zig_dep/) (external `build.zig.zon`
path-dep consumer) and [`examples/zig_host/`](../../examples/zig_host/).

## Consuming the package

Add zwasm to your `build.zig.zon` `.dependencies`, then in `build.zig`:

```zig
const zw = b.dependency("zwasm", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("zwasm", zw.module("zwasm"));
```

`@import("zwasm")` then exposes everything below. zwasm links libc (its
Engine carries a C allocator path).

## Types

All values are `union(enum)` / `struct` re-exported from
[`src/zwasm.zig`](../../src/zwasm.zig); borrowed handles (`Memory`,
`Global`, `Table`, `Caller`) stay valid for the owning `Instance`'s
lifetime.

| Type             | Purpose                                | Key methods (see source)                                                                                                                                                                           |
|------------------|----------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Engine`         | owns the allocator; parses + validates | `init(alloc, .{})` · `compile(bytes) → Module` · `deinit()`                                                                                                                                     |
| `Module`         | a validated module                     | `instantiate(.{}) → Instance` · `sectionCount()` · `deinit()`                                                                                                                                   |
| `Instance`       | an instantiated module                 | `typedFunc(Sig, name)` · `invoke(name, args, results)` · `memory()` · `global(name)` · `table(name)` · `exportFuncSig(name)` · `deinit()`                                                    |
| `TypedFunc(Sig)` | comptime-typed export handle           | `call(args_tuple) → Result` (multi-result via anon-struct return)                                                                                                                                 |
| `Memory`         | linear-memory view                     | `slice()` · `size()` · `read(T, addr)` · `write(addr, val)`                                                                                                                                     |
| `Global`         | exported global accessor               | `get() → Value` · `set(Value) !void` (`error.Immutable` on const)                                                                                                                                |
| `Table`          | exported table accessor                | `size()` · `get(idx)` · `set(idx, Value)` · `grow(delta, init)`                                                                                                                                 |
| `Linker`         | host-import builder                    | `init(engine)` · `defineFunc(mod, name, Sig, fn)` · `defineWasi(cfg)` · `defineMemory`/`defineGlobal`/`defineTable` · cross-module variants · `instantiate(module) → Instance` · `deinit()` |
| `Caller`         | host-fn first param                    | `memory()` · `allocator()`                                                                                                                                                                        |
| `Trap`           | the 12 spec trap conditions            | re-exported error set (`error.DivByZero`, `error.OutOfBoundsLoad`, …)                                                                                                                             |
| `Value`          | host-boundary value                    | `i32`/`i64`/`f32`(bits)/`f64`(bits)/`v128`/`funcref`/`externref` + `fromI32`/`fromI64`/`fromF32Bits`/`fromF64Bits`                                                                                 |

## Two embedding shapes

**No imports** — `Engine.compile` → `Module.instantiate(.{})` →
`Instance.typedFunc(...).call(...)`. See `examples/zig_dep` block (1).

**Host imports** — build a `Linker`, `defineFunc("env", "add", fn (*Caller, i32, i32) i32, hostAdd)`
(the Wasm signature is comptime-derived from the Zig fn; first param is
`*Caller`), then `linker.instantiate(&module)`. `defineWasi(.{ .args = …, .envs = … })`
satisfies any `wasi_snapshot_preview1` import (carries `args` + `envs`; preopens are
deferred — D-177). See `examples/zig_dep` block (2).

## Errors

`Engine.compile` → `error{ParseFailed, ValidateFailed}`. `Instance.invoke` /
`TypedFunc.call` → `InvokeError` = binding-shape errors
(`ExportNotFound`/`NotAFunc`/`ArgArityMismatch`/`ResultArityMismatch`) ∪ the
full `Trap` set, so callers branch on the exact spec condition.
`Linker.instantiate` → `LinkError` (`UnknownImport`/`ImportKindMismatch`/
`SignatureMismatch`/…). (`Module.instantiate`'s coarse `InstantiateFailed`
is tracked as D-275.)

## Design docs

- [`docs/zig_api_design.md`](../zig_api_design.md) — the rationale + ADR-0109 derivation.
