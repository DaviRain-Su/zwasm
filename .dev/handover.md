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

## Next task (autonomous)

**§15.2 — Coalescer detection logic** (first `[ ]` in §15 table). Layer concrete detection onto the
§9.8b/8b.1 coalescer scaffolding (ADR-0036): operand-stack vreg-numbering simulation + same-slot-event
subscription against the §9.8b/8b.2-c LIFO free-pool. **Exit: ≥5% bench-delta on loop-heavy fixtures**
(target from `private/notes/p8-8b1-coalescer-survey.md`). Step 0 survey FIRST — locate the scaffolding
(`CoalesceRecord` types, `func.coalesced_movs` slot, `isCoalesceCandidate`, `compile.zig` pipeline
placement) + the §9.8b/8b.2-c free-pool. This is Phase-8b bench territory → Step 5b bench-delta sub-step
applies. After §15.2: §15.3 class-aware (≥3% FP-heavy) → §15.4 SIMD + D-246 → **§15.5 D-245 win64**
(hard/remote) → §15.6 ClojureWasm → §15.P close. (Phase 15 stays IN-PROGRESS; not a phase boundary.)

## Step 0.7 (next resume)

This turn: **§15.1 close** — ADR-0148 (carve-out re-scope) + ROADMAP §15.1 row/narrative re-scoped &
flipped `[x]` + D-211 barrier updated (now moving/AOT, not Phase-15) + handover rewrite. **DOCS/scope
only — NO src/ change → no ubuntu kick** (code HEAD `45a94348`, ubuntu-verified OK last turn). Prior
chunk 2 (`45a94348`) ubuntu **OK**. **NOTE** (lesson `gate-tail-vs-exit-code`): benign `failed command:
…--listen=-` / `arm64/emit: failing op` next to a passing run = error-path test noise — EXIT authoritative.

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
