# 0191 — WASI-0.3 E2c: the WAIT-path drive (2-phase host source → callback re-entry)

- **Status**: Accepted 2026-06-16
- **Author**: claude (autonomous, WASI-0.3 campaign D-335 Unit E2c). Builds on the E2 survey + ADR-0190 (host stream peer) + ADR-0187 (stackless callback ABI).
- **Composes with**: ADR-0190 (E1/E3 host sink/source, E2b waitable-set builtins), ADR-0187 (`driveCallbackLoop` WAIT branch + `waitOn`). Within ROADMAP §9.0 Front D, Unit E.

## Context

`driveCallbackLoop`'s WAIT branch (`async.zig`: `.wait => ctx.waitOn(set)`) + the
P3 runner's `P3CallbackCtx.waitOn` (poll the `WaitableSetTable`) exist and are
unit-tested with a mock. But NO end-to-end test drives the real WAIT branch:
E1/E3 host peers complete a stream op IMMEDIATELY (the host sink/source is
always-ready), so the guest never blocks → never returns WAIT. E2c is the e2e
that exercises the WAIT branch through the real runner. The missing mechanism is
a host source that **blocks first, then delivers** (so the guest parks + returns
WAIT, and a later host event re-enters the callback).

Today `waitOn` only polls; if no member has a pending event it traps
`error.AsyncDeadlock`. In a synchronous single-task host there is no concurrent
actor to set the pending event between the guest's WAIT and the poll — so the
host itself must deliver, AT `waitOn` time, before polling.

## Decision

**Model a 2-phase host source + a `waitOn`-time delivery pass.** The host source
(E3, `WasiP2Ctx.host_sources`) gains a "deferred" mode: a guest `stream.read` on
it that finds no bytes ready **parks** (BLOCKED) and records the read request
`{end_handle, ptr, cap}`; then `waitOn`, BEFORE polling the set, gives each
parked host-source read a chance to deliver — it reads the now-available bytes
into the recorded `ptr`, marks the end `done`, and sets its `pending_event`
(`STREAM_READ`, count). `WaitableSet.poll` then returns that event and the loop
re-enters `callback(STREAM_READ, end, count)`.

Concretely:
1. **Parked-read state** — add `WasiP2Ctx.pending_reads: AutoHashMapUnmanaged(u32
   /*shared handle*/, struct { end: u32, ptr: u32, cap: u32 })`. `p2StreamFutureCopy`
   READ on a host source: if bytes ready → COMPLETED now (E3 path, unchanged); if
   the source is in deferred/empty phase → record the pending read + return BLOCKED
   (the end is already parked `async_copying` by `StreamFutureEnd.copy`).
2. **`waitOn` delivery pass** — before `set.poll`, for each set member that has a
   recorded pending read whose source now has bytes: copy bytes → guest `ptr`,
   `setPendingEvent(.{ .code = .stream_read, .index = end, .payload =
   ReturnCode.completed(n).encode() })`, clear the pending-read record. Then poll.
3. **Re-entry** — `driveCallbackLoop` calls `invokeCallback(STREAM_READ, end,
   payload)`; the guest callback reads the now-delivered count from the payload
   (or re-reads) and returns EXIT.

**The 2-phase trigger for the test**: the host source starts "armed but not
ready" (a per-source ready flag, flipped on after the first blocked read) so the
FIRST read parks and the `waitOn` pass delivers. Simplest impl: a
`host_source_armed` set; first read on an armed source → BLOCKED + record; the
`waitOn` pass delivers from `host.stdin_bytes`.

## Alternatives rejected

- **Immediate pending-event on join** (host sets the event when the readable end
  is joined, no real block) — rejected: doesn't exercise the BLOCK→WAIT→deliver
  sequence honestly; the guest never actually parks.
- **A real scheduler / second task** — rejected: heavier than the host-delivery
  pass; the synchronous `waitOn`-time delivery is the stackless-faithful minimum.
- **Deliver inside `waitable.join`** — rejected: join is set-membership only; the
  delivery belongs at the wait point (when the guest has yielded control).

## Consequences

- `waitOn` gains a host-source delivery pass (the runner's only "make progress"
  hook); `WasiP2Ctx` gains `pending_reads` + the armed-source flag.
- First e2e exercising `driveCallbackLoop`'s WAIT branch through the real runner:
  guest reads (parks) → WAIT(set) → host delivers → re-enter callback → EXIT,
  asserting the delivered bytes.
- Element marshalling reused from E1/E3 (`u8`). Multi-byte/typed + the return-
  future resolution remain later-slice gaps (tracked in D-335).
- After E2c the WAIT path is e2e-proven; the host-peer surface (E) can then grow
  to broader WASI-P3 interfaces (sockets/http) as separate slices.
