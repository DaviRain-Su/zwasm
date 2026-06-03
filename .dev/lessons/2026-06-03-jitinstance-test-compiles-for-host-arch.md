# A JitInstance.init regression test runs on the HOST arch — arch-pin arm64-only emit fixes

**Date**: 2026-06-03 · **Context**: D-239 br_on_null function-return emit (arm64-only)

## Observation

`JitInstance.init(gpa, wasm_bytes)` calls `compileWasm`, which **eagerly JIT-emits
every defined function for the host arch**. So a unit test that asserts a module
compiles is exercising the host's per-arch emit dispatch — arm64 on the Mac dev
host, x86_64 on `ubuntunote`.

I wired `br_on_null` function-return emit on **arm64 only** (the §10-Mac-gated
path), added a `JitInstance.init` regression test for it, and the Mac gate was
green. But the ubuntu (x86_64) `test-all` went RED: the x86_64 `br_on_null` emit
is still first-cut (forward-block targets only) → `UnsupportedOp` → `init` fails →
the test fails. The fix was correct; the *test* was arch-divergent.

## Rule

When a regression test does `JitInstance.init` (or anything that JIT-compiles)
on a feature wired for **one arch only**, it WILL fail on the other host. Either:
(a) wire BOTH arches, or (b) **comptime arch-pin the test**:
`if (comptime builtin.cpu.arch != .aarch64) return;` with a `// SIBLING-AT:
<x86_64 handler path>` comment (ADR-0122 D3 / `skip.zig` §arch-pinned; the
pre-commit `check_skip_helpers --gate` enforces the SIBLING-AT). Do NOT use a
raw `error.SkipZigTest` (baseline=0, gate-rejected — goes through `skip.zig`).

This recurs across the §10-exit endgame: per-arch JIT emit fixes (D-210
return_call_indirect, D-240 typed-ref tables, x86_64 br_on_null parity) land
arm64-first, so their `JitInstance` tests must be arch-pinned until x86_64 lands.

Related: [[2026-06-03-fp-walk-needs-every-frame-to-set-fp]] (other per-arch emit
gotcha); ADR-0122 D3 (SIBLING-AT); D-238 (x86_64 parity bucket).
