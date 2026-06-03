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
- **§15.2 mov-reduction — investigated, empirically unreachable → CLOSED `[x]`** (ADR-0149 + Revision).
  Slot-alias coalescing = ~0 headroom (gpr helpers already elide reg-resident movs; no vreg-to-vreg movs);
  re-targeted to spill-reload elim, then MEASURED (throwaway gpr counters via `--engine jit`): spill traffic
  = 2.7–5.6% of emitted instrs, adjacent-round-trip subset 1.4–2.2% → ≥5% perf unreachable. Residual peephole
  folded into §15.P. **Caution**: v2's spill traffic is LOW → regalloc-axis perf (§15.3) may also have thin
  headroom; the bigger wins are likely §15.4 SIMD + algorithmic.

## Next task (autonomous)

**§15.3 — Class-aware allocator** (first open `[ ]`; §15.2 closed/folded). Dual-pool GPR/FP register slots +
liveness type-tagging + tighter `spillBytes()` (ADR-0038/0040 scaffolding). Goal: FP-heavy code currently can't
use the FP register file well → dual-pool fixes it. **Exit: ≥3% FP-heavy** + aggregate ≥10% (with §15.4) at
§15.P. **⚠️ MEASURE HEADROOM FIRST** (lesson from §15.2): v2's spill traffic is only 2.7–5.6% of instrs — confirm
FP-heavy fixtures actually spill FP values to the wrong class / have ≥3% headroom BEFORE building the dual-pool
refactor (cheap probe: instrument FP spill counts on an FP-heavy fixture, like the §15.2 measurement). If headroom
is thin → re-scope per ADR-0149's caution (perf parity via §15.4 SIMD + §15.P aggregate). Step 0 survey: locate
the ADR-0038/0040 class-aware scaffolding + the current single-pool allocator (`regalloc.zig`). After §15.3:
§15.4 SIMD + D-246 → **§15.5 D-245 win64** (hard/remote) → §15.6 ClojureWasm → §15.P. (Not a phase boundary.)

## Step 0.7 (next resume)

This turn: **§15.2 measured + CLOSED** — subagent ran throwaway gpr/fp spill counters via `--engine jit` on
fib_loop/nestedloop/sieve → spill traffic 2.7–5.6% of instrs, adjacent round-trips 1.4–2.2% → ≥5% unreachable →
ADR-0149 Revision + ROADMAP §15.2 `[x]` folded into §15.P + §15.3 caution added. Instrumentation REVERTED (tree
clean). **DOCS/scope only — NO src/ change → no ubuntu kick** (code HEAD `45a94348`, ubuntu-verified OK). **NOTE**
(lesson `gate-tail-vs-exit-code`): benign `failed command: …--listen=-` / `arm64/emit: failing op` next to a
passing run = error-path test noise — EXIT authoritative.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile = `zig build test
-Dtarget=x86_64-windows-gnu`. windowsmini exec = `run_remote_windows.sh` (phase boundary).

## Deferred / open debt

- **D-258** (NOW) JIT-trampoline GC collect trigger (interp reclaims; JIT alloc path doesn't trigger
  yet — separate `*JitRuntime` root model). **D-211** (blocked-by) precise GcRootMap walker (moving/AOT).
  **D-257** (partial) 10 lesson `Citing` markers. **D-245** win64 host→JIT = §15.5. **D-246** arm64
  dot/extmul = §15.4. **D-255** C-API WASI io (ADR-0143). **D-254** rust 3-OS. **D-253** §13.2 host_info.
  **D-251** WASI in AOT. **D-249** win bench timing. **D-238** x86_64 EH thunk. D-210/234/237/229/231/204/209/213.

## Key refs

- ROADMAP §15 task table (15.1 DONE → 15.2 coalescer → … 15.5 D-245 … 15.6 ClojureWasm). Phase Status
  widget (14 DONE / 15 IN-PROGRESS). ADR-0146/0147/0148 (§15.1 GC); ADR-0128 §2 (non-moving conservative
  rooting); ADR-0036/0037/0038/0040 (coalescer + class-aware substrate); ADR-0135 (GC re-sequence).
