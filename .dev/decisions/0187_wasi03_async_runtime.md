# 0187 — WASI-0.3 async runtime: stackless callback ABI on a synchronous engine

- **Status**: Accepted 2026-06-15
- **Author**: claude (autonomous, WASI-0.3 campaign D-335 Unit D; spike of wasmtime `concurrent/` + CM `Concurrency.md`/`CanonicalABI.md`)
- **Composes with**: ADR-0186 (Front D / D-335), the shipped CM substrate (`src/feature/component/`). Within ROADMAP §9.0 Front D — not a deviation; this records the load-bearing architecture of the new `async.zig`.

## Context

Unit D is the WASI-0.3 (Component-Model async) crux: a runtime for `stream<T>` /
`future<T>` values + the async task/waitable model. zwasm's engine is
**synchronous** (interpreter + JIT, no native fibers/continuations). The naive
reading — "async needs stack-switching" — would make this impossible without a
major engine rework (and core stack-switching is explicitly OUT of scope for
WASI 0.3, ADR-0186).

## Decision

**Host CM-async via the stackless *callback ABI*, NOT fibers.** The Component
Model defines two async sub-ABIs (`Concurrency.md` §Summary): *stackful*
(requires the host to switch native stacks) and *stackless* (the guest provides
a `callback` funcidx, the `callback` canonopt 0x07). In the stackless model an
async-lifted export, when it would block, **returns control to a host event
loop** with a packed code (`EXIT`/`YIELD`/`WAIT`); the host re-enters via the
`callback` when an event is ready. A synchronous engine can drive this loop
directly — no fibers. **There is no hard blocker to full CM-async hosting on
zwasm's synchronous engine.**

Concrete shape (`src/feature/component/async.zig`, Zone-1 pure data, no
engine/invoke — mirrors `resource_table.zig`):

- **Stream/future handle table**: dense array + free list, index 0 reserved,
  `remove` tombstones (double-drop/use-after-drop trap), `MAX_LENGTH = (1<<28)-1`
  — the table Unit C's i32 handles index into. Entries are stream/future
  **ends** (readable/writable), each holding element type + `CopyState` + (later)
  a shared rendezvous buffer.
- **`CopyState`** = `{ idle, sync_copying, async_copying, cancelling_copy, done }`
  (`CanonicalABI.md` §Stream State).
- **`ReturnCode`** packing (wasmtime `futures_and_streams.rs`): `Blocked =
  0xffff_ffff`; else `(count << 4) | code` with code `0 Completed / 1 Dropped /
  2 Cancelled`, count in the high 28 bits (0 for futures).

**Rendezvous event model, NOT wasmtime's Rust-futures design.** wasmtime backs
each end with native async futures + channels; that is a Rust-runtime artifact.
zwasm uses the spec's own rendezvous: when a readable end has a pending buffer
and the writable end writes (or vice versa), copy immediately and fire the
`STREAM_READ`/`STREAM_WRITE` events. This is the seam that keeps the runtime
synchronous and small.

## Staged plan (bundle-within-unit; each lands green)

α handle-table CRUD + `CopyState` + `ReturnCode` (this cycle) · β `stream.read`/
`write` rendezvous + copy-progress · γ `cancel-read`/`write` + drop + the
IDLE→ASYNC_COPYING→DONE latch · δ `waitable-set.{new,join,wait,poll}` + event
delivery · ε futures (at-most-1 value) · ζ subtask + async-lowered import calls ·
η `task.return` + async export lifting + the callback event loop.

## Deferred (debt rows when reached, not now)

`thread.*` green threads, backpressure counters, and the same-component
non-number-type read+write copy (trap for now per `CanonicalABI.md`). These are
past the α–η critical path for a stream/future round-trip and do not gate the
unit's exit condition.

## Consequences

- A new `async.zig` module + its wiring; no change to the synchronous engine
  core. The callback ABI is invoked from the Zone-3 host (Unit ζ/η), not here.
- Unit-D exit condition: a WASI-0.3 stream/future handle round-trips through the
  table and a read/write rendezvous completes, 3-host green.
- Rejected: a fiber/continuation engine rework (unnecessary given the callback
  ABI; would violate the synchronous-engine design for zero benefit).
