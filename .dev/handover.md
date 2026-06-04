# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Active bundle

- **Bundle-ID**: 15.P-parity-vs-v1 (Phase-15 close: parity measured → investigate the one regression → close)
- **Cycles-remaining**: ~2–3 (root-cause D-265 memory-access gap → measure fix ROI → close §15.P + Phase 15)
- **Continuity-memo**: §15.P parity MEASURED + D-265 root-cause BISECTED (data: `bench/results/s15p_parity_vs_v1.md`).
  v1 built at `~/Documents/MyProducts/zwasm` (ReleaseFast); v2 ReleaseFast. Compare v1 `run <wasm>` (default JIT)
  vs v2 `run --engine=jit <wasm>` (compute-only per ADR-0136 → only gimli/heapsort/keccak/memmove JIT-runnable;
  TinyGo trap on fd_write). **Findings**: v2-jit FASTER on compute (all 12 SIMD 0.52–0.96×, keccak 20×, gimli,
  v128 loop 0.49×) but **~2.3× SLOWER when a loop body READS a loop-carried local** (= D-265). **Decisive A/B**:
  `a=a+CONST` (no i read) → 0.96× parity; `a=a+i` (reads i) → 2.30× — SAME i32.add. NOT memory/ALU-specific (was
  confounded: heapsort/memmove all index via i). Mechanism (inferred): v2's spill-everything slot allocator
  reloads the loop local each body use; v1 register-pins it. **CONTRADICTS §15.2/15.3 ~0-headroom folds**
  (ADR-0149/0150 measured spill % of TOTAL instrs — wrong proxy for hot-loop wall-clock). **W45 verdict: folded,
  data-backed** (v2 v128-loop 2× faster). Repro: `private/spikes/s15p-parity/w45_addi.wat` vs `w45_addc.wat`.
  **NEXT** = (1) confirm spill mechanism by dumping v2's emitted inner loop for w45_addi (read arm64
  `emit.zig`+gpr regalloc; find where `local.get` of a loop-resident local emits a slot reload); (2) measure a fix
  keeping loop-carried locals register-resident across the body (commit/revert per measure-first).
- **Exit-condition**: D-265 mechanism confirmed + a fix ROI-measured (landed if it holds, else documented why-not)
  + ADR-0149/0150 Revision note (headroom reachable on this pattern) → then §15.P close → widget 15 → DONE +
  Phase 16 inline expand. **DECISION FLAGGED to user**: fix the ~2.3× loop-local regalloc gap before v0.1.0
  (Phase 15 = "perf parity" → arguably in-mission), or ship + defer D-265 to Phase 16.

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
**See `## Active bundle` above** — §15.P parity is MEASURED (`bench/results/s15p_parity_vs_v1.md`); the bundle's
NEXT step is root-causing **D-265** (v2-jit memory-access ~2.2× slower than v1). §15.6 deferred (ADR-0152 → D-264);
§15.5 + 3-host reconcile DONE. §15.P is a hard PERF gate row but NOT a human-in-loop transition gate (no 🔒) —
autonomous (the close-vs-ship decision on D-265 is flagged to the user but does not stop the loop).

## Step 0.7 (next resume)

§15.5 CLOSED + §15.6 DEFERRED + §15.P parity MEASURED — all docs-only since (no code changed) → no ubuntu kick to
verify. Next resume = D-265 root-cause (read-only survey of arm64 load/store emit; first commits come when an
experiment lands). (`510ffce9`/`3a778080` already validated; do NOT revert.) **NOTE** (lesson
`gate-tail-vs-exit-code`): benign `failed command: …--listen=-` / SlotOverflow / `arm64/emit: failing op` next to
a passing run = error-path noise — EXIT authoritative. **D-262 process fix**: any NEW per-arch emit chunk → run
`run_remote_ubuntu test-all` (NOT narrow `test`) before discharge (cross-compile ≠ cross-run).

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile = `zig build test
-Dtarget=x86_64-windows-gnu`. windowsmini exec = `run_remote_windows.sh` (phase boundary).

## Deferred / open debt

- **STRUCTURAL RISKS (2026-06-04 retrospective, hub: lesson `session-retrospective-structural-risks`)** —
  the highest-stakes/most-orphan-prone: **D-261** (NOW, top stakes) GC-on-JIT conservative rooting has NO
  adversarial test → latent UAF (+ D-258). **D-262** (NOW) x86_64/win64 emit under-verified by the gate
  topology (cross-compile≠cross-run; D-260 symptom). **D-263** (NOW) parity-vs-v1 — MEASURED at §15.P
  (`bench/results/s15p_parity_vs_v1.md`); surfaced **D-265**. **D-210** (blocked-by) cohort root fix recurring at
  4 seams (D-142/206/210/245) — decide root-vs-patch.
- **D-265** (NOW, §15.P bundle) v2-jit ~2.3× slower when a loop body reads a loop-carried local (regalloc
  spill; bisected; contradicts §15.2/15.3 folds) — confirm mechanism + measure fix. **D-258** (NOW)
  JIT-trampoline GC collect trigger. **D-211** (blocked-by) precise GcRootMap.
  **D-257** (partial) 10 lesson `Citing`. **D-259** (note) spillBytes footprint. **D-255** C-API WASI io.
  **D-254** rust 3-OS. **D-253** §13.2 host_info. **D-251** WASI in AOT. **D-249** win bench. **D-238** x86_64
  EH thunk. D-234/237/229/231/204/209/213.

## Key refs

- ROADMAP §15 task table (15.1 DONE → 15.2 coalescer → … 15.5 D-245 … 15.6 ClojureWasm). Phase Status
  widget (14 DONE / 15 IN-PROGRESS). ADR-0146/0147/0148 (§15.1 GC); ADR-0128 §2 (non-moving conservative
  rooting); ADR-0036/0037/0038/0040 (coalescer + class-aware substrate); ADR-0135 (GC re-sequence).
