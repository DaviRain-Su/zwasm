# Cross-component async graph .wat is buildable — the exact spelling (ADR-0195 c-2b)

**Date**: 2026-06-17

## What was unverified

c-2b (guest↔guest async) needs a 2-component async graph fixture: component A
async-imports component B's async export. The Step-0 survey flagged buildability
as UNVERIFIED (would the toolchain parse+validate an async canon lower across a
composed `(component ...)` graph?). A spike (`private/spikes/async-graph/`)
confirmed: **YES, buildable** with `wasm-tools 1.251.0 parse` + `validate`
(the same one-step hand-WAT recipe as `adder_graph`, no compose tool).

## The spelling (two non-obvious requirements)

Combining the `adder_graph` composition pattern with the `async_exit_immediate`
async-lift pattern is NOT enough — the async cross-component import has two extra
requirements (found via `~/Documents/OSS/WebAssembly/component-model/test/async/
cross-abi-calls.wast`):

1. **The import's func type must be declared `async`**: `(import "tick" (func
   $tick async))` — NOT a plain `(func $tick)`. Otherwise validate fails with
   `the async canonical option requires an async function type`.
2. **`canon lower ... async` requires a `(memory ...)`** (subtask storage), even
   for a no-param/no-result func: `(core func $c (canon lower (func $tick) async
   (memory $mem "mem")))`. So component A needs its own core memory module.

The async-lowered import becomes a core func returning an **i32 status** (the
async call result code: RETURNED=2, etc.); the caller checks/drops it.

## Why it matters

The c-2b exit-condition fixture is buildable → the campaign target is real, not
toolchain-blocked. Reference for authoring: cross-abi-calls.wast (sync+async
pairs from $Bottom into $Top). Build recipe: `wasm-tools parse <f>.wat -o
<f>.wasm && wasm-tools validate --features all <f>.wasm`.

## Related

- ADR-0195 (multi-task async scheduler), c-2b cross-component routing.
- `test/component/README_adder_graph.md` (the hand-WAT graph recipe).
- spike `private/spikes/async-graph/two_async_components.wat` (the proven shape).
