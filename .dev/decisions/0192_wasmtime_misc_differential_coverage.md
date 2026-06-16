# ADR-0192 — wasmtime misc_testsuite full differential coverage campaign

- Status: Accepted
- Date: 2026-06-16
- Deciders: user-directed (2026-06-16), loop-executed
- Supersedes scope-narrowing of: ADR-0012 §6.2 (BATCH4 SIMD / BATCH5
  proposals deferred to P9/P10 — those phases are now DONE)

## Context

zwasm vendors only a hand-curated 42-fixture subset (BATCH1-3, mostly
parse+validate) of wasmtime's `tests/misc_testsuite/`. The current upstream
(`bytecodealliance/wasmtime` @897aa00d, 2026-06-16) carries **312 .wast**:
75 top-level core + gc 78 + simd 17 + memory64 11 + function-references 6 +
threads 12 + custom-page-sizes 4 + multi-memory/tail-call 2 +
component-model(+threading) 77 + winch 29 + shared-everything-threads 1.

The BATCH4/BATCH5 deferral (ADR-0012 §6.2) parked SIMD + all proposals while
P9/P10 were unbuilt. Those phases shipped; the corpus was never re-vendored.
wasmtime is a full Wasm-3.0 / WASI-0.3 reference implementation — its
misc_testsuite encodes regression + edge cases the official spec testsuite
misses (the same payoff just banked in the GC-corpus probe: 6 real engine
bugs the synthetic suite missed). The user directed (2026-06-16) wedging in a
phase that confirms zwasm has **no gaps** against wasmtime's full suite and
**fundamentally fixes** each one.

## Decision

Adopt wasmtime's full `tests/misc_testsuite/` as a **differential conformance
corpus** and run a multi-cycle campaign to close every real gap:

1. **Sweep harness** (`scripts/wasmtime_misc_sweep.sh` + shared distiller
   `scripts/wast_to_manifest.py`): convert every .wast via
   `wasm-tools json-from-wast`, distil to the runtime-runner manifest pair,
   run with full runtime asserts, tally PASS/FAIL/CONVFAIL/EMPTY per file.
   This is the GAP-FINDER (vs `regen_wasmtime_misc.sh`'s committed corpus).
2. **Triage** each FAIL: real zwasm gap vs harness/distiller artifact
   (`nan:canonical` expected values, v128/ref-typed asserts the distiller
   drops, env-import guests, component-model text json-from-wast can't lower).
   Real gaps → root-cause + TDD fix, NO blanket skip (no_workaround.md).
3. **Promote** legitimately-runnable fixtures into the committed corpus and
   wire the runtime runner into `test-all` once its corpus is green (lifting
   the Phase-6-era "NOT in test-all" exclusion that predates Wasm-3.0).

Out-of-scope-as-.wast (documented, not "skipped"): `winch/` (wasmtime
baseline-compiler codegen tests), `component-model*/` text that
`json-from-wast` cannot lower to core modules (needs component runtime, not a
core .wast gap), `shared-everything-threads/` (bleeding-edge proposal). Each
exclusion carries a one-line reason; none is a silent SKIP token.

## Consequences

- A 完成形 gate (100% spec / full-featured): differential vs a senior
  reference, not just the synthetic spec suite.
- The runtime runner gains a stable installed binary
  (`zig-out/bin/zwasm-wast-runtime-runner`, build.zig `installArtifact`).
- Campaign tracked as a handover `## Active rework campaign` (ADR-0153
  five-phase: I Investigation = the sweep + gap list; II Correctness = pin
  current behaviour; III/IV per-gap fix; V retrospective). Fully autonomous.

## Non-decisions

- Does NOT change P3/P6 single-pass or any §1/§2 inviolable. Fixes are
  spec-correctness, not an optimising tier.
- Does NOT cut a release (ADR-0156 unchanged).
