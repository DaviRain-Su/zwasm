# A custom Windows fault handler (VEH) must register First=1 — Zig auto-attaches its own at First=0 before main()

**Date**: 2026-06-06 · **Context**: D-292 B-core cycle II (ADR-0166) — production
internal-fault handler. POSIX worked; Windows surprised.

The B-core Windows handler installed a vectored-exception handler via
`RtlAddVectoredExceptionHandler(0, ...)` (`First=0` = back of the chain), expecting
to be the last-resort disposition. On the `test-internal-fault` gate, `zwasm
--__selftest-crash` on Win64 got **exit 3 with a Zig stack trace**, not our exit 70
— **our handler never ran**. Zig's runtime auto-attaches its OWN segfault VEH:
`std.start` → `maybeEnableSegfaultHandler()` (enabled when `runtime_safety`, i.e.
Debug/ReleaseSafe) → `std.debug.attachSegfaultHandler()` →
`windows.ntdll.RtlAddVectoredExceptionHandler(**0**, handleSegfaultWindows)`,
registered BEFORE `main()`. Among `First=0` handlers the chain runs in registration
order → Zig's (earlier) ran before ours (later) → it printed a trace + `_exit(3)`.

## Asymmetry with POSIX (why POSIX "just worked")

POSIX `sigaction` is **last-writer-wins** (replaces the disposition). Our install in
`main()` runs AFTER Zig's startup attach, so it OVERWROTE Zig's SIGSEGV handler →
ours won → exit 70. Windows VEHs **chain** (don't replace) → registration order /
First-flag decides, not recency-of-overwrite.

## Rule

- A custom Windows fault VEH that must be authoritative → register `First=1` (front).
  Installed in `main()` (after Zig's startup attach), the most-recently-registered
  `First=1` handler — yours — is called first (MSDN). `First=1` wins in BOTH Debug
  (beats Zig's `First=0`) and Release-no-safety (Zig attaches none). Fixed at
  `400c7006`.
- Verify the std mechanism from source, not by guessing: `grep RtlAddVectoredExceptionHandler`
  in the toolchain's `std/debug.zig` — the First flag is the whole game.
- The cross-platform `test-internal-fault` build step (`expectExitCode(70)`, in
  test-all) is what surfaced this — POSIX-only unit tests would have missed it.
  Behaviour that differs POSIX-vs-Windows needs a per-host behavioural gate.
