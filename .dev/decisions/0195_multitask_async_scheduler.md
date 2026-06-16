# ADR-0195 — Multi-task async scheduler for guest↔guest stream/future completion (D-335 remainder)

- Status: **Accepted (design) — IMPLEMENTATION PARKED, blocked-by D-305** (component linker). The design
  below is sound and stands for when the blocker lands; the *scheduler is downstream of cross-component async
  import routing*, which D-305 owns. See **Revision 2026-06-17** below. The Phase II(a) correctness gate
  (single-task `AsyncDeadlock`, `80ec1f63`) is the retained deliverable.
- Date: 2026-06-17

## Revision 2026-06-17 — implementation PARKED (blocked-by D-305)

A Phase-II design verification (before any scheduler code) found the campaign's exit-condition (a guest↔guest
`stream<u8>` rendezvous e2e) is **not in-process achievable today**, blocked one layer deeper than Phase I
assumed:

- **Async-lowered imports resolve to HOST functions ONLY.** Cross-component import resolution is name-match
  (`component.zig:~488`); there is no path routing a `canon lower`-with-`async` import call to a *guest*
  async callee in another instance.
- **`Subtask` (async.zig:397) is built but entirely UNWIRED** — zero production callers of `.resolve()` /
  subtask creation (only the `async.zig:~865` unit test). It was scaffolding for exactly this step.
- **CM-async spawns a subtask ONLY via an async-lowered import targeting an async callee in ANOTHER
  component instance** = cross-component composition. There is NO intra-component multi-task path (one async
  export per instance; no `spawn` builtin; cyclic self-import disallowed).
- Therefore guest↔guest needs **D-305 (the fully-general component linker)** to route async-import→guest-callee
  FIRST; the ADR-0195 scheduler (`TaskTable` + per-task dispatch) is the layer ABOVE that. Building it now =
  speculative infra with no real consumer (spike §2). PARKED until D-305.

What was retained as genuine value: **Phase II(a)** pinned single-task `AsyncDeadlock` (the behavior the
scheduler would generalise) — a permanent regression guard. The design (TaskTable + cooperative round-robin)
is recorded here intact; revive this ADR's Decision when D-305 lands. Lesson:
`2026-06-17-guest-guest-async-is-downstream-of-component-linker`.
- Relates: ADR-0187 (stackless callback ABI), ADR-0189 (ζ2 wiring / WasiP2Ctx async state), ADR-0190/0191
  (host-peer Unit E + WAIT path), lesson `2026-06-16-stackless-stream-completion-needs-host-peer`. Builds on
  the committed ζ1 `Subtask` machinery (1e3e814b).

## Context

zwasm's CM-async is **stackless** (ADR-0187): a guest's async export is driven by `driveCallbackLoop`
(`async.zig:124`), re-entering the guest `callback(event, p1, p2)` until it returns `EXIT`. Host-backed
streams complete because a host sink/source acts as the synchronous 2nd actor (Unit E; E1 stdout / E3 stdin).

**The gap (not a bug — an acknowledged design boundary):** a *guest↔guest* `stream.read` that blocks returns
to the callback loop with no continuation, and there is **no second guest task** to write the peer end →
`waitOn` polls an empty set → `AsyncDeadlock`. The single-task runner is architecturally complete for ONE
task; it cannot rendezvous two guest tasks.

Investigation (Phase I, 2026-06-17) confirmed the **Zone-1 machinery is already complete**: `Subtask`
state machine + lenders + resolve→SUBTASK event (`async.zig:397`), `SharedStream`/`SharedFuture` rendezvous
with peer-handle notify (`:482`, `StreamFutureEnd.copy` `:209`), `WaitableSet`/`WaitableSetTable` event
delivery (`:290`). What is missing is purely the **driver**: `driveCallbackLoop` drives one task; a second
task (an async-lowered import's guest func) is never re-entered.

## Decision

Add a **cooperative round-robin multi-task scheduler** as a clean, additive extension of the callback ABI:

1. **`TaskDescriptor` + `TaskTable` (Zone-1, `async.zig`)** — per-component table (mirrors `StreamFutureTable`
   shape): `{ task_id, callback_funcidx, set_index, state: {ready, waiting_on_set, done} }`. Pure data.
2. **Scheduler loop (Zone-3, the P3 runner)** — generalise the single-task `driveCallbackLoop` consumer into a
   loop over the `TaskTable`: drive each `ready` task's callback; for a `waiting_on_set` task, poll its set and
   deliver a pending event if present; mark `done` on `EXIT`. Terminate when all tasks `done`, or trap
   `AsyncDeadlock` when *all* tasks are `waiting_on_set` AND no set has a pending event (generalises the
   current single-task deadlock check).
3. **Async-lowered import → new task** — when a guest calls a `canon lower`-with-`async` import, mint a
   `Subtask` (exists) AND enqueue a `TaskDescriptor` for the callee so the scheduler drives it. Cross-task
   events already route correctly: a `SharedStream.write` on task A's end deposits the rendezvous result in
   task B's end `pending_event` (`copy()` `:209`), which B's next poll delivers — the rendezvous code is
   peer-agnostic and unchanged.

The main export seeds task 0 in the `TaskTable`; a pure single-task component is just a 1-entry table (zero
behaviour change — the regression guard).

## Alternatives rejected

- **Fibers / stackful coroutines** — rejected by ADR-0187 (and re-rejected here): the callback ABI already
  encodes continuations as guest-visible state; fibers would duplicate that + add per-task native stacks.
- **Preemptive scheduler** — unnecessary; CM-async is cooperative (tasks yield at canon calls / blocked I/O).
  Round-robin over the ready set is sufficient and deterministic (testability).
- **Amend ADR-0187** — not needed; multi-task concurrency is at the *application* level (guest calls async
  imports), not a new engine concurrency primitive. ADR-0187's "stackless, no fibers" is fully intact.

## Incremental plan (bundle `wasi-p3-multitask-scheduler`, correctness-first)

- **(a) Correctness gate FIRST** — confirm/strengthen the characterization net for the 8+ single-task async
  e2e fixtures (`component_wasi_p3.zig`) so the `driveCallbackLoop` generalisation cannot silently regress
  EXIT / YIELD / WAIT / host-peer COMPLETION / single-task `AsyncDeadlock`.
- **(b)** `TaskDescriptor` + `TaskTable` (Zone-1) + the 1-entry-table refactor of the driver (single-task
  behaviour byte-identical; full async corpus green).
- **(c)** async-lowered-import → enqueue-task wiring + the scheduler dispatch loop.
- **(d)** the smallest guest↔guest e2e: `async_two_tasks_stream_rendezvous.wat` (main mints a `stream<u8>`,
  spawns a subtask, writes; subtask reads → both COMPLETE + return). Exit-condition of the bundle.
- **(e)** adversarial corpus: both-tasks-read → `AsyncDeadlock`; drop-mid-rendezvous → `DROPPED`; subtask
  cancel-before-start → `CANCELLED`.

Each step keeps the full test net green (P3/P6 single-pass invariants untouched — this is the interp/host
driver, no JIT/codegen surface).

## Consequences

- Closes the last D-335 functional gap; enables (later, user-only) the `-Dwasi` `.p2→.p3` default flip.
- `driveCallbackLoop`'s contract generalises from "drive THE task" to "drive the task TABLE"; the single-task
  path is the 1-entry special case.
- New adversarial surface (race/join/cancel timing) — paid down by the (a)+(e) correctness corpus, which is a
  hard gate, not optional.
