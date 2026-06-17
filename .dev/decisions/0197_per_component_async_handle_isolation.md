# ADR-0197 — Per-component async handle-table isolation for the cross-component graph runner (D-463)

- Status: **Accepted (design) — correctness-first bundle OPEN 2026-06-18**. Phase I investigation done
  (the GraphAsync survey + the `pending_graph_reads` re-key analysis below); Phase II (adversarial isolation
  fixture + characterization) is the next-cycle gate BEFORE any Phase IV redesign code.
- Date: 2026-06-18
- Refines: ADR-0195 d-b-2 (the graph-shared `StreamFutureTable`/`SharedTable` was the least-change path that
  made cross-component future/stream rendezvous work; this ADR closes its deliberate handle-isolation
  simplification, tracked as **D-463**).

## Context

`GraphAsync` (`src/api/component_graph.zig`) gives ALL child components ONE shared `StreamFutureTable`
(`streams`) + ONE `WaitableSetTable` (`sets`) + ONE `SharedTable` (`shared`). Every `graphStream*`/
`graphFuture*`/`graphWaitable*` builtin resolves `ctx.as.streams.get(handle)` against that one table
regardless of which child is calling (`GraphFutureCtx = { as: *GraphAsync, elem_size }` — no child identity).

So a future/stream handle minted in child A is a bare i32 that is **directly valid in child B's lookup** at the
same index. This is functionally correct for a TRUSTED composed graph (the `two_async_components_*` fixtures
pass, mutation-proven) but **violates Component-Model handle isolation**: each component instance owns its own
index space; a handle crossing a boundary TRANSFERS (ownership moves) rather than being globally index-visible.
Concretely, child B can reach child A's *un-granted* handles by guessing indices — the same
cross-component-security family as the D-305 boundary error-trap.

## Decision

Make the async handle tables **per-component**, with **call-time end-transfer** at the async boundary:

1. **`StreamFutureTable` (`streams`) and `WaitableSetTable` (`sets`) move from `GraphAsync` to per-`GraphChild`.**
   Each child gets its own end/handle index space (mirrors `WasiP2Ctx.{streams,sets}`, which is already
   per-instance). `GraphFutureCtx` gains `streams: *StreamFutureTable` + `sets: *WaitableSetTable` pointing at
   the **calling child's** tables (each `future_ctxs` entry is already installed per-child, so the injection
   point exists).

2. **`SharedTable` (`shared`) STAYS graph-shared.** The `Shared` rendezvous objects (SharedStream/SharedFuture
   buffers) are the actual shared channel both ends point to via `StreamFutureEnd.shared`. They are NOT
   guest-addressable by raw index — a guest reaches a rendezvous only THROUGH an end it legitimately owns. So
   keeping them graph-shared does not breach isolation; it is the correct "shared backing channel, separately
   owned ends" Component-Model shape.

3. **End-transfer at the boundary.** When child A calls B passing a stream/future end handle (`installAsyncBoundary`
   / `asyncBoundaryParamTrampoline`), the trampoline: looks up the handle in A's `streams` → `StreamFutureEnd`
   `{..., shared: S}`; **removes it from A's table** (ownership moves); **mints a NEW B-local handle** pointing
   to the same shared `S`; passes the B-local handle to B. The `.shared` field (the rendezvous id) is stable;
   only the owning table-index changes.

4. **`pending_graph_reads` re-keys from raw end-handle → shared-slot id.** It currently keys parked
   cross-component reads by the reader-end handle (`nt.waitable`). Once tables are per-component, two children's
   same-valued handles would collide in this graph-level map. The rendezvous (`SharedStream`) is graph-unique,
   so key the parked-read map by the **shared-slot id** (`end.shared`) instead — graph-unique by construction.

## Alternatives rejected

- **Status quo (graph-shared tables).** The D-463 simplification — functionally correct for trusted graphs but
  a spec-fidelity + sandboxing miss; the project bar is 100% spec + sandboxing-triad-everywhere, and the
  design-priority posture reworks deliberate v2 simplifications rather than locking them in.
- **Shared table + per-end `owner` tag + ownership check on access.** Smaller (one field + one assert +
  retag-on-transfer) and closes the *security* leak, but keeps ONE global index space: B's first mint would be
  index "2" because A used "1", not an independent "1". That is a guest-observable divergence from a
  spec-compliant engine's independent index spaces → a partial measure, not the canonical design. Rejected in
  favour of true per-component tables (option above).

## Correctness-first plan (II before IV — hard self-gate)

- **Phase II (correctness-assurance FIRST).** (a) Characterization: the 6 `two_async_components_*` fixtures stay
  green at every commit (they are the trusted-graph regression net). (b) **Adversarial isolation fixture**
  `two_async_components_stream_isolation.wat`: child A mints TWO streams (granted w1 + private w2), async-calls
  B passing ONLY w1; B's `tick` attempts `stream.write` on the index of A's PRIVATE end. Today this SUCCEEDS
  (global table — the leak); the test asserts it TRAPS (B's per-component table has no such index). Authored as
  a RED test (`expectError`) pinning the post-fix guarantee. This is the 正しさ担保 gate; no Phase IV code lands
  before it is red-then-driving.
- **Phase IV (implementation).** Per-component tables → `GraphFutureCtx` injection → boundary end-transfer →
  `pending_graph_reads` re-key. Full async test net green at EVERY commit; per-component table lifetime managed
  with the child (init/deinit moves from `GraphAsync` to `GraphChild`).
- **Phase V retro.** Mark D-463 discharged; add a Revision note to ADR-0195 d-b-2 (its simplification is now
  superseded by this isolation pass).

## Consequences

- Closes D-463; brings cross-component async to spec-canonical handle isolation (untrusted composition safe).
- `GraphAsync` shrinks to genuinely graph-level state (`tasks`/`callbacks`/`current_task_id`/`shared`/
  `pending_graph_reads`); `streams`/`sets` become per-child — the same per-instance shape the single-component
  WASI-P2/P3 runners already use, so the two paths converge.
- No public API change; no WIT/fixture-semantics change for the 6 trusted fixtures (only internal handle
  indices, opaque to conformant guests). New adversarial fixture added.
- P3/P6 single-pass invariants untouched (interp/host driver only; no JIT/codegen surface).
