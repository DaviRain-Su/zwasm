# x86_64 codegen is locally TDD-able via `-Dtarget=x86_64-macos` under Rosetta (SHORT runs)

**Date**: 2026-06-16
**Context**: D-461 SIMD-spill (x86_64-specific codegen, no native x86_64 dev host — Mac is M4 Pro arm64).

`runI32Export`-style tests compile a module with the **build-target arch's** JIT
and execute it. For x86_64-specific codegen bugs (e.g. `resolveXmm` spill
reject, regalloc class-boundary OOB) the failing path is x86_64-only — so on an
arm64 Mac the default `zig build test` can't see it, and the only verification
was a slow ubuntu-gate round-trip.

**`zig build test -Dtarget=x86_64-macos` builds the x86_64 test runner and runs
it under Rosetta 2 — and it WORKS for unit tests** (verified: rc=0, no signal
issues, including JIT-generated x86_64 SIMD code executing under Rosetta
translation). This turns x86_64 codegen into a **local red→green TDD loop**.

## Caveat + why it's safe here

The D-134 lesson (`2026-05-17-d134-rosetta-2-signal-translation-limit`) found
Rosetta 2 hits a **signal-delivery race** on the LONG `test-all` run (24,000+
spec fixtures, trap-signal-heavy). That does NOT apply to a short unit-test run
(`zig build test`, no giant fixture loop). So: use `-Dtarget=x86_64-macos` for
**focused unit/codegen tests** (fast local x86_64 verification); keep the real
`test-all` x86_64 verification on the native ubuntu gate (never Rosetta).

A Zig `index out of bounds` / bounds panic under this path is a **real
deterministic codegen bug**, NOT a Rosetta artefact (Rosetta translates, it
doesn't inject Zig bounds panics) — trust it.

## Rule

When fixing x86_64-only codegen with no native x86_64 host: build a focused
characterization test, run `zig build test -Dtarget=x86_64-macos` (Rosetta) for
the local red, fix, re-run for green — then let the ubuntu gate confirm on real
x86_64. Don't burn ubuntu round-trips for the inner TDD loop.
