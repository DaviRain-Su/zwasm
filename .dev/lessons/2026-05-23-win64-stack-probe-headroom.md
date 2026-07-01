# Win64 stack-probe requires ≫16 KiB headroom (commit-pattern early overflow)

**Keywords**: ADR-0105, STACK_GUARD_HEADROOM, Win64, stack-probe,
runaway, EXCEPTION_STACK_OVERFLOW, GetCurrentThreadStackLimits,
commit pattern, R3, D-162

**Citing**: commit `1e2d716d` (R3 cycle 6 fix), `17917f07` (R3
close).

## What we tried

ADR-0105 D6 set `STACK_GUARD_HEADROOM = 16 KiB` initially based on
POSIX trap-stub-epilogue + signal-handler-frame budget. Mac aarch64
+ Linux x86_64 trap `assert_exhaustion runaway` cleanly with this
headroom. Win64 windowsmini crashed exit 253
(EXCEPTION_STACK_OVERFLOW) despite:

- `computeStackLimit` returning a sane non-zero value
  (`GetCurrentThreadStackLimits` worked correctly).
- `*(rt + stack_limit_off)` reading the same value as
  `rt.stack_limit` (extern struct layout correct, R15 valid).
- JBE rel32 patched to a non-zero disp pointing at the trap stub's
  first byte (`MOV [R15+trap_flag_off], 1`, 0x41).
- INT 3 prepended to trap stub did NOT change exit code → probe
  never reaches the stub.

6 cycles of investigation ruled out: stack_limit=0, layout drift,
JBE patch off-target, encoder bug.

## What we learned

Windows raises `EXCEPTION_STACK_OVERFLOW` BEFORE SP descends to
`LowLimit + 16 KiB` due to **commit-pattern early overflow**. Per
MSDN, `GetCurrentThreadStackLimits` returns the reserved range
boundaries, but the OS commits stack pages lazily. When the
commit-region grows down and hits some Windows-internal threshold
(possibly related to `SetThreadStackGuarantee`'s 0 default or
guard-page chain semantics), `STACK_OVERFLOW` fires WAY before SP
reaches `LowLimit`.

For runaway recursion at ~64 bytes/frame, 16 MiB / 64 = 262K
calls would be needed to reach `LowLimit + 16K`. The OS exception
fires far sooner.

**Bumping Win64 headroom to 1 MiB resolves it.** Recursion still
runs ~250K+ calls before probe, but Windows commit-pattern
exceptions fire well within that window — they get caught by the
probe AT `LowLimit + 1 MiB` instead of the OS-imposed earlier
threshold.

## Recipe

```zig
pub const STACK_GUARD_HEADROOM: usize = if (builtin.os.tag == .windows)
    1024 * 1024
else
    16 * 1024;
```

Mac/Linux keep 16 KiB (no change to the working baseline). Win64
uses 1 MiB.

## Verification

- runaway + mutual-runaway both PASS on windowsmini with 1 MiB
  headroom (per /tmp/win.log line 31388-31392 from cycle 6 run).
- No regression on Mac aarch64 or Linux x86_64 (headroom
  unchanged for them).

## Forbidden retro-conclusions

- "GetCurrentThreadStackLimits is broken" — it's not; it returns
  correct reserved bounds. The OS-side overflow trigger is just
  not at the reserve boundary.
- "Probe is broken on Win64" — encoding + patching + runtime
  state are all verified correct.
- "Just disable the probe on Win64" — the probe is needed to
  cleanly convert stack overflow to `Error.Trap`; without it,
  the OS terminates the process.

## Related

- ADR-0105 D6: tunable per amend (the headroom bump fits
  the explicit tunability clause; no ADR amendment needed for
  experiment, but Revision history note is welcome at R3 close).
- D-162: closed by this fix + ADR-0105 cycle 1-2 work.
- `src/platform/stack_limit.zig::STACK_GUARD_HEADROOM`.
- `.dev/handover.md` "R3 cycle 1-6 evidence" (will be moved here
  at R3 close).
