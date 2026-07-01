# two_async_components_stream.wat — synchronous cross-component async stream rendezvous

ADR-0195 step (d-c-1): the smallest guest↔guest async **stream** multi-element
transfer across a component graph, in the SYNCHRONOUS (write-before-read) case.

## Shape

- **Component B** exports `tick: async func(stream<u8>)`. Its core `tick`
  receives the writable end handle, stores 3 bytes `{10,20,12}` in B's memory, and
  `stream.write(w, &bytes, 3)` — depositing the elements into the graph-shared
  rendezvous.
- **Component A** imports `tick` and exports `run: async func() -> u32`. A's core
  `run` mints a `stream<u8>` via `stream.new` (readable `r` + writable `w`),
  async-calls `tick(w)` (B runs synchronously during the call and writes), then
  `stream.read(r, &out, 3)` → COMPLETED(3), reads the 3 bytes, sums them
  (`10+20+12 == 42`), and `task.return`s the sum.
- The stream handle crosses A→B as a bare i32: both ends are minted into the
  **graph-shared** `StreamFutureTable` over the **graph-shared** `SharedTable`
  (`GraphAsync.{streams,shared}`), so `w` is valid in B's `stream.write` lookup
  and resolves to the SAME rendezvous slot A reads. Only the i32 crosses.
- B writes BEFORE A reads (B runs synchronously during the async call), so A's
  read never BLOCKs. The blocking (read-first → BLOCKED → pollSet) path is d-c-2.
- The test (`component_tests.zig`, "ADR-0195 d-c-1 …") asserts A's OWN task
  result == 42, proving the multi-byte payload crossed B→A (not just both
  completing).

## Build

`wasm-tools` 1.251.0 (no `compose`/`wac`); the graph is hand-authored as a nested
`(component …)` with `(instance (instantiate …))` + `(with …)`. Stream
read/write lower to `(handle, ptr, count) -> i32` (the `count` param distinguishes
streams from the single-shot future ops).

```sh
wasm-tools parse two_async_components_stream.wat -o two_async_components_stream.wasm
wasm-tools validate --features all two_async_components_stream.wasm
```
