# `should_gate_windows.sh --record` stamps HEAD, not the kicked-at SHA

**Date**: 2026-06-17

## What happened

The batched windows gate (ADR-0076 D8) flow is: kick `run_remote_windows.sh
test-all` in the background at the end of turn N (HEAD = `X`), then "after the
next-cycle green verify, run `--record`". But `--record` does
`git rev-parse HEAD > .dev/last_windowsmini_sha` — and by the time you verify
(turn N+1), HEAD has chained PAST `X` to `Y`. Recording `Y` claims windows
tested `Y` when it only tested `X`; the commits in `X..Y` silently never enter
any windows batch (the next `LAST..HEAD` count starts at `Y`).

Concrete: windows kicked at `fab05508`, turn N+1 chained two `wasi:random`
commits to `21b0c574`, then `--record` stamped `21b0c574`. The random commits
(adapter dispatch + a handler) would have skipped windows forever. Corrected by
writing `fab05508` back into the (gitignored, per-machine)
`.dev/last_windowsmini_sha`; the gate then correctly showed `3/12 since
fab05508`.

## Rule

`--record` must capture the SHA windows ACTUALLY ran against, i.e. **HEAD at
kick-launch time**, not HEAD at verify time. Practical discipline until the
script takes an arg: note the kicked-at short SHA when launching the windows
job; at the next Step 0.7, after confirming `[run_remote_windows] OK`, write
that SHA into `.dev/last_windowsmini_sha` directly (or run `--record` only if no
commits were chained since the kick). A non-ABI batch deferring is fine — the
point is the in-flight commits stay COUNTED, not that they gate immediately.

## Related

- ADR-0076 D8 (batched windows gate), `feedback_windowsmini_gate` memory.
- Same family as `gate-tail-vs-exit-code` (trust the authoritative artifact,
  not a convenience shortcut that drifts from ground truth).
