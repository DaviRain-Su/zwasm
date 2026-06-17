# two_async_components_future.wat — cross-component async future rendezvous

ADR-0195 step (d-b-2): the smallest guest↔guest async **future** value transfer
across a component graph.

## Shape

- **Component B** exports `tick: async func(future<u32>)`. Its core `tick`
  receives the writable end handle, stores `42` in B's memory, and
  `future.write(w, &42)` — depositing the value into the graph-shared rendezvous.
- **Component A** imports `tick` and exports `run: async func() -> u32`. A's core
  `run` mints a `future<u32>` via `future.new` (readable `r` + writable `w`),
  async-calls `tick(w)` (B runs synchronously during the call and writes), then
  `future.read(r, &out)` → COMPLETED, reads `42`, and `task.return`s it.
- The future handle crosses A→B as a bare i32: both ends are minted into the
  **graph-shared** `StreamFutureTable` over the **graph-shared** `SharedTable`
  (`GraphAsync.{streams,shared}`), so `w` is valid in B's `future.write` lookup
  and resolves to the SAME rendezvous slot A reads. Only the i32 crosses.
- The test (`component_tests.zig`, "ADR-0195 d-b-2 …") asserts A's OWN task
  result == 42, proving the value crossed B→A (not just both tasks completing).

## Build

`wasm-tools` 1.251.0 (no `compose`/`wac`); the graph is hand-authored as a nested
`(component …)` with `(instance (instantiate …))` + `(with …)`. Future
read/write lower to `(handle, ptr) -> i32` (single-shot — no count param).

```sh
wasm-tools parse two_async_components_future.wat -o two_async_components_future.wasm
wasm-tools validate --features all two_async_components_future.wasm
```
