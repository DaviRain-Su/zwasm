# Guest↔guest async stream completion is downstream of the component linker (D-305)

**Date**: 2026-06-17

## What happened

Opened the ADR-0195 multi-task async campaign to close the D-335 "guest↔guest
stream COMPLETION" gap (gates the `-Dwasi` p2→p3 default flip). Phase I
estimated a clean ~400 LOC scheduler (`TaskTable` + per-task dispatch on
`driveCallbackLoop`), claiming the Zone-1 `Subtask`/`SharedStream`/`WaitableSet`
machinery was "ready". A Phase-II design verification (BEFORE writing scheduler
code) found the campaign's exit-condition is blocked one layer deeper.

## The real blocker

In CM-async, a **subtask** is created ONLY by calling an async-lowered import
whose callee is an async function **in another component instance** — i.e.
cross-component composition. Concretely in zwasm today:

- Async-lowered imports resolve to **host functions only** (write-via-stream,
  stream-read, …). Cross-component import resolution is **name-match**
  (`component.zig:~488`), with no path routing a `canon lower`-with-`async`
  import to a *guest* async callee.
- `Subtask` (`async.zig:397`) is **built but entirely unwired** — zero
  production callers of `.resolve()` (only the `async.zig:~865` unit test).
- There is **no intra-component multi-task path**: one async export per
  instance; no `spawn` builtin; cyclic self-import disallowed.

So two concurrent GUEST tasks rendezvousing on a stream needs **D-305 (the
fully-general component linker)** to route async-import→guest-callee FIRST. The
multi-task scheduler is the layer ABOVE that. D-305 is itself `blocked-by`
(disproportionate effort, deferred) and p3 is not urgent → the scheduler is
parked, not driven into speculative infra (spike §2: no real consumer).

## Rule

- Before opening/continuing an async-feature campaign, check the **callee
  resolution path**: an async-lowered import to a GUEST callee = cross-component
  = D-305. Host-peer (Unit E) is the only in-process async-completion path until
  D-305 lands.
- A Phase-I "the machinery is ready" claim is not enough — verify there is a
  REAL in-process test scenario (a committed `.wat`) before estimating impl. The
  campaign's design gate (ADR-0153 II, design-before-code) caught this and saved
  ~400 LOC of speculative scheduler against a blocked dependency. That is the gate
  working, not a failure.
- Retained value when parking: the Phase II(a) characterization test
  (single-task `AsyncDeadlock`, `80ec1f63`) is a permanent regression guard the
  scheduler would have needed anyway.

## Closing note (2026-06-17 PM) — the downstream dep is satisfied

The D-305 SYNC cross-component linker landed (`component_graph.zig` @2b9b14ee). The async-import→guest-callee
routing is a ~100 LOC mirror of the sync `boundaryTrampoline`, so the scheduler is no longer "downstream of an
unbuilt linker" — it is now the frontier. ADR-0195 flipped PARKED → UNBLOCKED (Rev 2026-06-17 PM); the real
remaining work is scheduler-internal (`TaskTable` + multi-task driver), not linker routing. The lesson's
sequencing insight held: the linker genuinely had to come first.

## Related

- ADR-0195 (Revision 2026-06-17 PM, UNBLOCKED), D-305 (component linker, sync common shapes DONE), D-335
  (guest↔guest now gated on the ADR-0195 scheduler, not D-305), lesson
  `2026-06-16-stackless-stream-completion-needs-host-peer` (the single-task half).
