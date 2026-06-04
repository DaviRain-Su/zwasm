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

## Next task (autonomous)

**§15.4 — SIMD-op JIT coverage sweep (D-246, partial)** (first open `[ ]`; §15.2+§15.3 folded). CORRECTNESS gap
(NOT bench-gated — build regardless). **DONE this turn**: arm64 `dot`/`extmul` hole CLOSED — 13 ops
(`078ffde5` encoders + `ef9876b0` 12 extmul + `5ddfdc5c` dot), both layers (found `lower_simd` lacked the arms
→ dead on both arches), JIT-execution-verified, x86_64 OK.
**NEXT = the residual 13 arm64-missing SIMD ops** (x86_64 has op files, arm64 lacks emit+mostly lowering →
interp-only on JIT): `i{8x16,16x8}.{add,sub}_sat_{s,u}` (8 → SQADD/UQADD/SQSUB/UQSUB), `i{16x8,32x4}.extadd_pairwise_*_{s,u}`
(4 → SADDLP/UADDLP), `i16x8.q15mulr_sat_s` (1 → SQRDMULH). **SAME RECIPE** as dot/extmul: add NEON encoders to
`inst_neon_arith.zig` (clang-verify each via `clang -c`+`otool -tvVj`), add lowering arms to `lower_simd.zig`
(check each — extmul/dot were un-lowered), op files + `op_simd_int_arith` helpers (`emitV128Binop` for the
binops; extadd_pairwise is a 1-src op so a different helper), manifest imports/tuple + count bump, edge_cases JIT
fixtures. Then D-246 fully resolved. After §15.4: perf ports W43/44/45 = **measure-first** (perf-roi lesson) →
**§15.5 D-245 win64** (hard/remote) → §15.6 ClojureWasm → §15.P parity.

## Step 0.7 (next resume)

This turn: **§15.4/D-246 dot+extmul CLOSED** — 3 commits (`078ffde5` encoders, `ef9876b0` 12 extmul + lowering,
`5ddfdc5c` dot), 13 ops both layers, JIT fixtures green, x86_64 cross-compile OK; D-246 → partial (residual = 13
sat-arith/extadd/q15mulr ops). Also recorded perf-measure-first lesson (`43ecd845`). **CODE changed → ubuntu kick
QUEUED** (scope `test`); Step 0.7 next resume verifies (`tail -3 /tmp/ubuntu.log`) — red → revert to `45a94348`.
**NOTE** (lesson `gate-tail-vs-exit-code`): benign `failed command: …--listen=-` / SlotOverflow / `arm64/emit:
failing op` next to a passing run = error-path test noise — EXIT code authoritative.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile = `zig build test
-Dtarget=x86_64-windows-gnu`. windowsmini exec = `run_remote_windows.sh` (phase boundary).

## Deferred / open debt

- **D-258** (NOW) JIT-trampoline GC collect trigger (interp reclaims; JIT alloc path doesn't trigger
  yet — separate `*JitRuntime` root model). **D-211** (blocked-by) precise GcRootMap walker (moving/AOT).
  **D-257** (partial) 10 lesson `Citing` markers. **D-245** win64 host→JIT = §15.5. **D-246** (partial)
  dot/extmul DONE; residual 13 sat-arith/extadd/q15mulr ops = §15.4 next. **D-259** (note) spillBytes footprint. **D-255** C-API WASI io (ADR-0143). **D-254** rust 3-OS. **D-253** §13.2 host_info.
  **D-251** WASI in AOT. **D-249** win bench timing. **D-238** x86_64 EH thunk. D-210/234/237/229/231/204/209/213.

## Key refs

- ROADMAP §15 task table (15.1 DONE → 15.2 coalescer → … 15.5 D-245 … 15.6 ClojureWasm). Phase Status
  widget (14 DONE / 15 IN-PROGRESS). ADR-0146/0147/0148 (§15.1 GC); ADR-0128 §2 (non-moving conservative
  rooting); ADR-0036/0037/0038/0040 (coalescer + class-aware substrate); ADR-0135 (GC re-sequence).
