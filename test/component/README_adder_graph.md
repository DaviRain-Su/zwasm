# p17 Component Model fixture: adder_graph (composed multi-component graph)

Minimal real composed component graph exercising nested `component`
sections (binary id 4) + component `instance` sections (id 5) with
cross-instance import→export wiring. A true cross-component func call:
`add-five(x)` in child A calls `adder(x, 5)` in child B.

## Why hand-written component WAT (not a compose tool)

`wasm-tools` 1.247.0 has **no** `compose` subcommand and **no** `wac`
on PATH. `wasm-tools component link` exists but is *shared-everything
dynamic linking* (core-module union via the dynamic-linking
convention), not WIT-level composition. The component-model **text
format** natively expresses nested `(component ...)` +
`(instance (instantiate ...))` with `(with ...)`, and `wasm-tools parse`
assembles it directly — so the outer graph is authored in WAT and
assembled in one step. No intermediate `embed`/`new` per child needed.

## Reproduce

```sh
wasm-tools parse adder_graph.wat -o adder_graph.wasm
wasm-tools validate --features component-model adder_graph.wasm
# behaviour check (needs wasmtime):
wasmtime run --invoke 'add-five(10)' adder_graph.wasm   # => 15
```

## Structure (`wasm-tools print`)

Two nested `(component ...)` at outer scope + two outer
`(instance (instantiate ...))`:

- child **$B**: core module exports `adder (param i32 i32)(result i32)`;
  `canon lift` → component func `adder: func(a:u32,b:u32)->u32`; exported.
- child **$A**: imports `adder` (component func); `canon lower` it to a
  core func; core module imports `"deps" "adder"` and exports
  `add-five (param i32)(result i32)` = `adder(x, 5)`; `canon lift` →
  `add-five: func(x:u32)->u32`; exported.
- outer: `(instance $b (instantiate $B))`,
  `(instance $a (instantiate $A (with "adder" (func $b "adder"))))` —
  B's exported `adder` satisfies A's import — then
  `(export "add-five" (func $a "add-five"))`.

Top-level binary section IDs (verified): `4,4` (two nested components),
`5,5` (two component instances), plus component-type/alias/export.

## Behaviour

`add-five(10)` → A calls B's `adder(10, 5)` → `15`. This is a real
cross-component call, not a structural-only fallback.

## Files

- `adder_graph.wat`   — source (single-file component WAT)
- `adder_graph.wasm`  — the fixture (549 B)
