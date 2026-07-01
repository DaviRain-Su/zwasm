# ADR-0198 — Split v128-on-JIT fixtures out of `runner_gc_test.zig`

- Status: **Accepted** (2026-06-18). Autonomous file-size split per ADR-0099 D1
  (hard-cap resolution = split-ADR OR FILE-SIZE-EXEMPT marker).
- Date: 2026-06-18
- Relates: ADR-0099 (file-size discipline reframe), ADR-0128 (GC-on-JIT test
  extraction that created `runner_gc_test.zig`), ADR-0164 (the `runner_trap_test.zig`
  sibling split), D-460 (v128-GC JIT emit), D-461 (SIMD register-spill awareness).

## Context

Adding the D-461 FP-`replace_lane` spill fixture pushed
`src/engine/runner_gc_test.zig` to 2001 lines — one over the 2000 hard cap
(`file_size_check.sh --gate` → exit 1). The file mixed two distinct concerns:

1. **GC op-semantics** — i31 / struct / array / ref.eq / ref.test / ref.cast
   round-trips through the JIT (the file's original ADR-0128 charter).
2. **v128-on-JIT** — D-460 v128-GC field round-trips + the D-461 SIMD
   register-spill-correctness fixtures (every one force-spills a v128 and reads a
   lane back; a non-spill-aware handler surfaces `UnsupportedOp`).

The D-461 spill family is still growing (FP-replace_lane this cycle; the D-034
GPR/FP-scalar cohort still ahead), so concern (2) has its own change cadence and
was the recurring source of cap pressure — exactly the pattern that earlier drove
`runner_test.zig → runner_gc_test.zig` (ADR-0128) and `→ runner_trap_test.zig`
(ADR-0164).

## Decision

Extract the v128-on-JIT block (lines 215–607, ~393 LOC) into a focused sibling
`src/engine/runner_v128_jit_test.zig`, registered via `src/zwasm.zig`'s `test {}`
block alongside the other runner suites.

File-size smell (ADR-0099): **P1** (v128/SIMD lane + load ops under the JIT are a
spec-defined closed sub-language ≥300 LOC) **+ P3** (independent change cadence:
the D-461 spill track) **+ P4** (test-isolation), with **0 negatives** (test
files import nothing from each other → no N1 circular / N2 pub-leak; the block is
393 LOC → not N3 shallow). Both halves land comfortably under the soft cap
(GC 1607, v128 411).

## Consequences

- `runner_gc_test.zig` returns to its ADR-0128 charter (GC op-semantics only).
- Future D-461 / D-034 spill fixtures land in `runner_v128_jit_test.zig`, keeping
  the cap pressure off the GC suite.
- No behaviour change — pure test relocation; the same fixtures run, discovered
  through the same `test {}` aggregation.
