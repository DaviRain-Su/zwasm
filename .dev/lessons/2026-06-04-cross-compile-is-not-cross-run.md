# Cross-COMPILE ≠ cross-RUN — newly-lowered ops with existing per-arch emit need a per-arch RUN

**Date**: 2026-06-04
**Citing**: D-260 (x86_64 SIMD emit bugs found by windowsmini test-all `730a198b`); §15.4/D-246
chunks B/C (`ef9876b0`/`1029e5b4`).

## What happened

§15.4/D-246 added `lower_simd.zig` arms making 26 SIMD ops JIT-reachable (extmul/dot/sat-arith/
extadd/q15mulr). The arm64 emit was new (clang-verified encoders + Mac test-all green). The x86_64
emit ALREADY EXISTED (B107 handlers) but had never been reachable (no lowering), so it was never
runtime-tested. Verification did: arm64 RUN (Mac edge_cases) + `zig build -Dtarget=x86_64-windows-gnu`
(cross-COMPILE) + ubuntu `run_remote_ubuntu test` (narrow scope, not test-all). D-246 was marked
RESOLVED + the debt discharged.

Then windowsmini `test-all` (the first x86_64 FULL run of these ops) caught it: `i16x8.q15mulr_sat_s`
+ `i16x8.extadd_pairwise_i8x16_s` produce WRONG results on x86_64 (`expected 1, got 0`) — latent
x86_64 emit bugs (q15mulr's PMULHRSW misses the -1×-1 saturation) shipped as "RESOLVED."

## Rule

- **A successful cross-COMPILE (`-Dtarget=…`) proves only that the code TYPE-CHECKS + links for that
  target — NOT that the emitted machine code is correct.** Per-arch *emit correctness* needs the op to
  actually RUN on that arch (or at minimum a clang-verified byte-level encoder test + an algorithmic
  proof).
- **When you make an op reachable that has PRE-EXISTING, never-exercised per-arch emit (e.g. adding a
  shared `lower_simd` arm that routes to an old x86_64 handler), you have NOT verified that handler —
  you've EXPOSED it.** Run it on each arch (`run_remote_ubuntu test-all` for x86_64; windowsmini for
  win64) before declaring the op done. The narrow `run_remote_ubuntu test` scope is NOT enough — it
  skips the spec/edge_cases SIMD runners.
- Encoder-level: clang-verify each NEW encoder (as the arm64 D-246 work did), but that does NOT cover
  a wrong RECIPE in an existing handler (right encoders, wrong algorithm/operand-order/missing-sat).
  Only a per-arch RUN of the op catches a recipe bug.
- Don't discharge a multi-arch op debt on single-arch-run + other-arch-cross-compile. Discharge needs
  each shipped arch RUN green.
