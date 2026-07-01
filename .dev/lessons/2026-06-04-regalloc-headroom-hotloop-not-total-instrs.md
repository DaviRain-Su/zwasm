# Regalloc headroom is a hot-loop measure, not a %-of-total-instructions measure

**Date**: 2026-06-04 · **Type**: observation (D-265 rework campaign close, ADR-0153)

## What happened

§15.2/§15.3 folded the regalloc-axis perf tasks (ADR-0149/0150) on a measurement of
**spill traffic as a fraction of total emitted instructions**: GPR spill 2.7–5.6%, FP
spill 0% → "v2's deterministic-slot emit is already tight, ~0 headroom." That proxy
was wrong for one important pattern. The §15.P parity bench then caught a real **2.30×**
slowdown vs v1 on loops whose body reads a loop-carried local (`a=a+i`), A/B-bisected
against a no-`i` control at parity (`a=a+CONST`, 0.96×). The D-265 rework campaign added
register-homing of hot locals (single-pass, P3/P6 intact — v1 is the existence proof) and
recovered arm64 `w45_addi` **2.30×→0.97×**; on x86_64 the reads-`i`/control differential
collapsed **2.4×→1.0×**. Verified 3-host (Mac arm64 + Rosetta x86_64-macos + ubuntu
x86_64-linux test-all green).

## Rules

1. **A reload inside a 3-instruction hot loop is ~0% of the program but ~2× of that
   loop's wall-clock.** "% of total instructions" hides hot-path cost — it is the wrong
   proxy for loop-resident-value perf. Measure the *hot loop's* per-iteration cost (A/B
   a fixture that does vs does not exercise the suspected pattern), not the program-wide
   spill ratio.
2. **An A/B control localizes the mechanism.** `a=a+i` vs `a=a+CONST` (identical loop,
   only the body's local-read differs) proved it was loop-local residency, not memory/ALU
   — the earlier "memory-access 2.2×" framing was confounded by array indexing reading `i`.
3. **measure-first cuts both ways**: it correctly folded the *slot-alias coalescer* and
   *FP dual-pool* (genuinely 0 headroom — those stay folded), but a fold based on the
   wrong proxy must be RE-OPENED when a sharper benchmark contradicts it. Negative results
   are scoped to what they measured; a loop-isolated bench is sharper than a program-wide
   ratio. Corrects the over-generalization in [[2026-06-04-perf-roi-measure-before-build]].
4. **Correctness gate for residency-homing**: a stale cached/homed local = a miscompile
   (the x86_64 first try `f31affa1` was reverted after ubuntu caught i64+recursive
   miscompiles — homed regs are C-ABI callee-saved but JIT fns never push/restore them).
   Pin behaviour with adversarial fixtures (stale-after-`local.set`, loop-carried,
   multi-local-pressure) FIRST, and RUN on every shipped arch
   ([[2026-06-04-cross-compile-is-not-cross-run]]) — cross-compile ≠ cross-run.

Data: `bench/results/s15p_parity_vs_v1.md`. ADRs: 0149/0150 Revision, 0153.
