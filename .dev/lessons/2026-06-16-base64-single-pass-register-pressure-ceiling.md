# A 13.6× perf outlier was mostly the single-pass register-pressure ceiling, not a fixable bug

**Date**: 2026-06-16
**Context**: Front ④ perf (D-450). `all_engine_matrix.md` showed shootout/base64
at zwasm-jit 781 ms vs wasmtime 57 ms (**13.6×**) — a stark outlier (other
shootout benches 1.5–4×). It looked like a specific fixable hotspot; profiling
(ADR-0153 Phase I, `sample` + `ZWASM_DEBUG=jit.dump`) showed it's **mostly the
design ceiling**.

**Finding**: the hot loop (wasm func 52, a branchless base64-encode kernel: 15
i32 locals + ~30 mask constants + a deep i32 bit-shuffle expression tree) emits
**59–68% spill traffic** (sp-relative ldr/str; ~5:1 vs ALU). Cause: only 8 GPRs
are allocatable (arm64 X9-13+X20-22); the kernel's live set blows past 8, so the
deterministic-slot LSRA spills nearly every operand-stack value AND every
constant. Cranelift/LLVM win base64 via GLOBAL register allocation + LICM
(hoisting the masks into registers across the loop) — a whole-function /
loop-invariant optimization a **single-pass, per-op-emit backend structurally
cannot do** without an optimizing tier (forbidden, §1.3/§3.2).

**Classify A vs B before chasing a perf gap** (the load-bearing discipline):
- **Class B (optimizing-tier ceiling)** = global regalloc / CSE / LICM / GVN. A
  single-pass backend can't close it without violating the no-optimizing-tier
  principle. The honest outcome is ACCEPT + document — NOT chase to parity. The
  *bulk* of base64's 13.6× is class B.
- **Class A (single-pass-legal peephole)** = a local emit-time fix needing no IR
  pass. base64 surfaced two: re-materialize a spilled `i32.const` via `mov`
  (cheaper than spill+reload) and elide store-then-immediately-reload-same-slot
  pairs (a 1-deep reg cache in the spill helpers). Est. ~1.3–2× + a GENERAL
  spill-heavy benefit — worth a focused ADR-0153 rework (correctness-FIRST: the
  spill machinery is D-265-class subtle), but it sits ATOP a class-B gap and will
  NOT reach parity.

**How to apply**: when a bench is an outlier, profile to the emitted-code level
and classify A vs B with evidence (spill ratio, what an optimizing compiler does
differently) BEFORE committing to "fix it." A high ratio is often mostly the
accepted single-pass price; only the class-A residue is worth single-pass work.
Cross-ref [[feedback_perf_measure_first]] (measure ROI before building) and the
D-265 regalloc rework (the prior single-pass register-pressure campaign).
