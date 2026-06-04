# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase 15 (Performance parity with v1 + ClojureWasm) IN-PROGRESS.** Phase 14 (CI) / 13 (C API) /
  12 (AOT) DONE.
- **§15.1 GC reclamation + conservative rooting — DONE** (`be4357be`; ADR-0146/0147/0148). The
  mark-sweep collector now collects under heap pressure + FREES/REUSES dead memory:
  - chunk 1a `5de51a69` `stack_limit.nativeStackHigh()`; 1b `b46960db` object-start-validated
    conservative native-stack scan (`scanNativeStackRoots`, `scan_native_stack` flag); 1c `55503da7`
    (ADR-0146) heap-pressure collection trigger (`root_scope.maybeCollect`, wired into interp
    `allocateStruct`/`allocateArray`); 2 `32aaec94` + exit `be4357be` (ADR-0147) external free-list
    reuse → alloc-loop cursor BOUNDED.
  - **Re-scoped at close (ADR-0148 carve-out)**: precise `zir.GcRootMap` stack-map walker + §12.5
    AOT GC-root serialization are NOT needed for a non-moving collector (ADR-0128 §2) → deferred to
    **D-211** (barrier: moving collector OR AOT GC-root serialization). JIT-trampoline collection
    trigger (separate `*JitRuntime` root model) = **D-258**.
- **§15.2 + §15.3 (regalloc-axis perf) — both measured ~0 headroom → CLOSED `[x]`/folded** (ADR-0149/0150).
  §15.2: GPR-spill traffic 2.7–5.6% of instrs → ≥5% unreachable. §15.3: **FP-spill = 0%** (nbody/matrix never
  overflow the 13 V-regs; resolution already class-aware per D-036) → ≥3% unreachable; dual-pool not built;
  `spillBytes()` footprint cleanup = **D-259**. **Pattern: v2's deterministic-slot emit is already efficient
  (low/zero spill) — regalloc-axis optimizations have no headroom. This = v2 likely near v1 parity.** §15.P
  reframed to parity-vs-v1 (not fixed ≥10%). Remaining perf lever = §15.4 (SIMD/compute axis + D-246 emit hole).
- **§15.4 SIMD coverage + perf ports — DONE** (D-246 `1029e5b4` + perf ports measured→folded ADR-0151). 26 ops
  closed both arches; v2 already 0.5–0.8× the comparator median (0/12 lag >3×). W45 loop-persistence → §15.P.
- **§15.5 D-245 win64 host→JIT trampoline — DONE** (`510ffce9`, clobber-trampoline). **test-all 3-host GREEN**:
  Mac + ubuntu x86_64 + windowsmini win64 (rc=0, no SEGV). D-260 x86_64 SIMD bugs (q15mulr/extadd) surfaced by the
  win64 run + FIXED `3a778080`, also 3-host green. Root fix D-210 NOT taken (per-seam patch; see structural risks).

## Next task (autonomous)

**§15.6 ClojureWasm CI — ⏸ DEFERRED** (ADR-0152 → D-264, user-confirmed). `ClojureWasmFromScratch` is itself a
from-scratch v1 redesign IN PROGRESS (branch `cw-from-scratch`, v0.0.0, deps=zlinter only, no `zwasm` dep, no CI);
stable cw = v0.5.0 on `main`. Its zwasm-v2 consumer is cw's OWN future phase → nothing to validate today. v2
package-consumability already proven by `examples/zig_host/` (ADR-0109). Barrier (D-264) dissolves when cw-v1 lands
committed `@import("zwasm")` source.
**NEXT = §15.P Phase 15 close — parity-vs-v1 (D-263 HARD gate)**. Now the last active §15 task (§15.6 deferred;
3-host reconcile DONE, D-245 landed). Required: (1) **v2-vs-v1 steady-state bench** on ≥3 loop-heavy + ≥1 SIMD-loop
fixture (build/find v1 baseline from `~/Documents/MyProducts/zwasm` clone) — no unexplained regression vs v1; (2)
**W45 loop-isolated measurement** (≥50M-iter v128-local loop, no-op-baseline subtracted, per ADR-0151 — if v2's
per-iter v128-reload dominates, RE-OPEN W45) + record the already-efficient finding + opportunistic D-259. Then
widget 15 → DONE + Phase 16 inline expand. Step 0: survey `scripts/run_bench.sh` + `bench/` harness + v1 clone
buildability. **Note**: §15.P is a hard gate row but NOT a human-in-loop transition gate (no 🔒) — autonomous.

## Step 0.7 (next resume)

§15.5 CLOSED (D-245 `510ffce9` + D-260 `3a778080`, 3-host test-all green). §15.6 DEFERRED (ADR-0152 → D-264).
Next resume = **§15.P parity-vs-v1 close** — Step 0 is a bench-harness survey (`scripts/run_bench.sh` + `bench/` +
v1 clone buildability), not a code chunk → no prior ubuntu kick to verify. (`510ffce9`/`3a778080` already
validated; do NOT revert.) **NOTE** (lesson
`gate-tail-vs-exit-code`): benign `failed command: …--listen=-` / SlotOverflow / `arm64/emit: failing op` next to
a passing run = error-path noise — EXIT authoritative. **D-262 process fix**: any NEW per-arch emit chunk → run
`run_remote_ubuntu test-all` (NOT narrow `test`) before discharge (cross-compile ≠ cross-run).

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile = `zig build test
-Dtarget=x86_64-windows-gnu`. windowsmini exec = `run_remote_windows.sh` (phase boundary).

## Deferred / open debt

- **STRUCTURAL RISKS (2026-06-04 retrospective, hub: lesson `session-retrospective-structural-risks`)** —
  the highest-stakes/most-orphan-prone: **D-261** (NOW, top stakes) GC-on-JIT conservative rooting has NO
  adversarial test → latent UAF (+ D-258). **D-262** (NOW) x86_64/win64 emit under-verified by the gate
  topology (cross-compile≠cross-run; D-260 symptom). **D-263** (NOW) "v2≈v1 parity" never measured vs v1 →
  hard §15.P gate. **D-210** (blocked-by) cohort root fix recurring at 4 seams (D-142/206/210/245) — decide
  root-vs-patch.
- **D-258** (NOW) JIT-trampoline GC collect trigger. **D-211** (blocked-by) precise GcRootMap (moving/AOT).
  **D-257** (partial) 10 lesson `Citing`. **D-259** (note) spillBytes footprint. **D-255** C-API WASI io.
  **D-254** rust 3-OS. **D-253** §13.2 host_info. **D-251** WASI in AOT. **D-249** win bench. **D-238** x86_64
  EH thunk. D-234/237/229/231/204/209/213.

## Key refs

- ROADMAP §15 task table (15.1 DONE → 15.2 coalescer → … 15.5 D-245 … 15.6 ClojureWasm). Phase Status
  widget (14 DONE / 15 IN-PROGRESS). ADR-0146/0147/0148 (§15.1 GC); ADR-0128 §2 (non-moving conservative
  rooting); ADR-0036/0037/0038/0040 (coalescer + class-aware substrate); ADR-0135 (GC re-sequence).
