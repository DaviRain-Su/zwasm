# Perf ROI is only knowable by measurement — measure headroom before building; commit/revert liberally

**Date**: 2026-06-04
**Citing**: user guidance 2026-06-04 ("perf は ROI 高いものを判定するには実測する
しかないので、柔軟にコミット・リバートしていい"); §15.2 fold (ADR-0149) + §15.3
fold (ADR-0150).

## What happened

Phase 15's regalloc-axis perf tasks were scoped with fixed bench targets
(§15.2 coalescer ≥5%, §15.3 class-aware ≥3%, combined ≥10%) set BEFORE the v2
emit model solidified. Two measurements disproved both premises:

- **§15.2** (ADR-0149): a structural read of `arm64/{emit,gpr}.zig` showed the
  gpr spill helpers already elide every reg-resident mov + v2 emits no
  vreg-to-vreg movs, so slot-alias coalescing detects nothing. A follow-up
  throwaway spill-counter measurement (via `zwasm run --engine jit`, reverted)
  put total GPR-spill traffic at 2.7–5.6% of emitted instrs → ≥5% unreachable.
- **§15.3** (ADR-0150): a throwaway FP-spill counter measured **0%** FP-spill on
  nbody/matrix (13 V-regs never overflow) → ≥3% unreachable; dual-pool has no
  FP spills to eliminate.

Both folded. v2's deterministic-slot spill-everything emit is already tight on
memory traffic — the inefficiencies the tasks targeted don't exist at the
assumed scale (a positive signal: v2 is likely near v1 parity).

## Rule

- **Measure the headroom BEFORE building a perf optimization.** A ROADMAP perf
  target is a hypothesis, not a fact; the codebase's actual inefficiency
  decides reachability. Cheapest probe: throwaway instrumentation (spill/op
  counters) run on representative fixtures via `--engine jit`, often delegated
  to a subagent that reverts the edits (tree stays clean).
- **Commit/revert/spike liberally for perf** (user-blessed 2026-06-04). The cost
  of a benched-then-reverted experiment ≪ the cost of shipping a no-op
  optimization (or a W54-class miscompile). For SIMD perf ports (§15.4 W43/44/45)
  it is fine to implement → bench → revert if the measured ROI is low; record
  the measurement (ADR/lesson) so the negative result isn't re-litigated.
- Correctness gaps (e.g. D-246 arm64 dot/extmul emit hole) are NOT bench-gated —
  build those regardless; only PERF chunks need the measure-first gate.
