# A wasi:cli component's exit code can only signal ok/err — never a numeric sentinel

**Date**: 2026-06-16
**Context**: Front ① wasip3 conformance fixtures (cli-env / cli-args / cli-stdin).
A "wasip3 inputs not delivered to the guest" bug (D-449) turned out to be a
**fixture-design flaw, not a runtime bug** — the env/args/stdin paths all work.

**The trap**: `wasi:cli/exit` is `exit: func(status: result<_, _>)` — it carries
ONLY an ok/err discriminant, no numeric code. So a guest's
`std::process::exit(N)` maps: `0` → `exit(Ok)` → host exit_code **0**; **any N>0**
→ `exit(Err)` → host exit_code **1**. A conformance fixture that signalled success
with `std::process::exit(42)` and asserted `host.exit_code == 42` was therefore
**unsatisfiable regardless of behaviour** — exit(42) collapses to exit_code 1,
the SAME as the failure arm `exit(1)`. The test read "input came back empty" when
in fact the input was delivered fine; the success signal just couldn't survive
the exit ABI.

**Proof** (instrumented + isolated): `p2GetEnvironment` was called exactly once
with `envs.len=1`, `realloc` wired, and the list bytes laid out correctly
(`k='WASI_TEST'@…+9 v='ok'@…+2`, 16B tuple stride). Switching the fixture to
`Ok("ok") => exit(0)` flipped `host.exit_code` to 0 → env WAS read. cli-args +
cli-stdin had the identical flaw and also pass once re-signalled with exit(0).

**How to apply**: a wasi:cli (P2/P3) conformance fixture MUST signal success with
`std::process::exit(0)` (or normal return) and failure with any non-zero exit;
NEVER a distinctive numeric code as a success sentinel — the
`exit(result<_,_>)` channel erases it. To assert WHICH value was read, have the
guest write it to stdout (capturable via `host.stdout_buffer`) instead of
encoding it in the exit code. Meta-lesson (cf.
[[2026-06-16-gap-matrix-subagent-verify-against-spec]]): a "found bug" from a
new test must itself be verified against the host ABI — the test can be wrong.
