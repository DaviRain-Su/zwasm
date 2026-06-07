# Trust exit codes, not output tails, for gate verification

**Date**: 2026-05-28
**Citing**: cycle-65 retrospective (`1e88350f` + `2f33dc06` shipped
with broken local Mac test; ubuntu kick failed at cycle 66 resume).

## What happened

Cycle 65 added "multi-memory" to `spec_assert_runner_wasm_3_0.zig`'s
PROPOSALS list (5 → 6 entries) but missed updating the pinning test
at `:440` (`expectEqual(@as(usize, 5), PROPOSALS.len)`). The bug was
local — Mac `zig build test` would have failed clearly. But the
commit message claimed "test-all + lint green on Mac aarch64",
shipped to origin, and Ubuntu kick exposed the lie on resume.

## Root cause

The cycle-65 gate verification used:

```sh
zig build test-all 2>&1 > /tmp/test_run.log; echo "EXIT=$?"; tail -3 /tmp/test_run.log
```

`tail -3` on a 5.7MB output captured the LAST runner's summary
(`wast_runner: 1158 passed, 0 failed`) — but the *failing test* was
in a different layer (`zig build test` proper). The `EXIT=$?` line
DID print `EXIT=1` (the build failed), but the format made it easy
to skim past — the eye drops to the tail summary and reads "green".

The narrower `zig build test` would have shown the failure cleanly,
but I went straight to `test-all` for thoroughness and lost the
signal in the volume.

## Rule

When verifying a gate before commit:

1. **Always check `echo $?` / `EXIT=$?` first**, before any tail/grep.
   If non-zero, gate failed; stop and find the error.
2. If using `test-all` or any multi-step gate, **explicitly grep for
   `error:` / `failed:` / `fail \d` patterns in the full log**, not
   just the tail. Multi-step gates have many runners; only some
   emit a final summary line.
3. **Never claim "X green" in a commit message without re-checking
   the exit code from this exact run.** The `[gate_commit]` lines
   from the pre-commit hook don't substitute — they only cover the
   `--fast` shape that skips `zig build test`.

## Mechanical detection

A `scripts/verify_gate_green.sh` wrapper that fails loudly when:

- `zig build test-all` exit non-zero
- OR any line in the output matches `^error:` or `failed:` outside
  a known-stderr-noise allowlist (e.g., negative-case
  `compileWasm: ... → validate StackTypeMismatch` lines that are
  expected output from assert_invalid tests)

would catch this class of bug at gate time. Filed as future-cycle
infra (no debt row yet — small enough to land in a single
infrastructure cycle when surface area justifies).

## Update 2026-06-04 — `failed command:` next to OK is benign

`run_remote_ubuntu.sh` logs can show `failed command: …/test …
--seed=0x… --listen=-` (or, transiently under parallel build, a
`run exe …-hello`) right above `[run_remote_ubuntu] OK`. This is NOT a
gate hole: the script keys OK/FAIL off `ssh … || die_step` (the real
`zig build test-all` exit code), verified `TESTALL_EXIT=0` on ubuntu.
The `--listen=-` lines are zig's test-server noise — unit tests that
exercise abort/panic/trap spawn child test processes which exit
non-zero *by design*; the server restarts and the step nets exit 0.
Corollary to rule #1: the **exit code is authoritative**; a stray
`failed command:` in the human-readable tail is not a red turn. (Cost
a full Step-0.7 re-investigation on the §13.5 zig_host resume — direct
`./zwasm-zig-host-hello; echo $?` = 0 settled it.)

## Update 2026-06-08 — codegen / trap / signal test-stderr noise removed

`zig build test` previously also leaked ~10 lines of codegen diagnostics
(`arm64/emit: unsupported op …`, `SlotOverflow`, `x86_64/op: UnsupportedOp`,
`trap kind=unreachable`, `internal error — caught a fatal signal`) from
negative/error-path tests. These were unconditional `std.debug.print` (66
codegen sites → routed through the env-gated `support/dbg.zig` under module
`"codegen"`, silent unless `ZWASM_DEBUG=codegen`) and the production CLI
trap-surface (`cli/run.zig surfaceTrap`/`surfaceJitTrap`) + the internal-fault
signal handler (`platform/signal.zig faultHandler`), now comptime-elided under
`builtin.is_test` (no test asserts their text; production prints unchanged).
After this, the ONLY residual line is the documented-benign `failed command:
…--listen=-` above — exit code stays authoritative.

## Related

- ADR-0076 D3 (3-host gate via ubuntu kick) — the kick was the
  *second line of defense* that caught the bug, but the first line
  (local Mac gate) should not have let it through.
- `.claude/skills/continue/GATE.md` — gate workflow (revisit
  exit-code primacy when this lesson stabilises).
