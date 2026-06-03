# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Active bundle

- **Bundle-ID**: 15.2-reload-elim (redundant spill-reload elimination — bench-gated ≥5%, RE-TARGETED from
  slot-alias coalescing per ADR-0149; correctness-critical, W54-divergence-prone)
- **Cycles-remaining**: ~3–5 (reload-headroom measurement → emit staging-reg cache → 2-arch → bench)
- **Continuity-memo**: **ADR-0149 (this turn): the scaffolded slot-alias coalescer has ~0 headroom** —
  structural read proved `arm64/gpr.zig` helpers already elide all reg-resident movs (`gprStoreSpilled` reg-case
  `{}`, `gprLoadSpilled` reg-case returns the reg), locals↔spill are separate frame regions, and v2 emits NO
  vreg-to-vreg movs. So `slots[src]==slots[dst]` detects nothing. **RE-TARGET**: a SPILLED vreg used N× re-emits
  `gprLoadSpilled` (an `LDR`) each use → cache "vreg→staging-reg" during emit + skip the reload when the value is
  still resident + the reg un-clobbered. Emit-local (does NOT touch regalloc slots → lower W54 risk than
  slot-alias). **W54 lesson STILL governs**: the staging-reg cache MUST invalidate at every call + branch target;
  test Mac aarch64 FIRST; differential suite (spec+realworld both arches) is the correctness guard. Coalescer
  scaffolding (`src/ir/coalesce/pass.zig`, ADR-0035/0036) left DORMANT (no-op; its stale "detection lands in
  8b.1-d" doc comment to be marked superseded when the §15.2 emit chunk lands).
- **PROGRESS**: Step-0 surveys done (2 Explore digests) → **slot-alias coalescer disproven (ADR-0149, this turn)**
  + ROADMAP §15.2 re-scoped to redundant spill-reload elimination + §15.3 combined-target note updated.
  **NEXT = reload-headroom measurement**: confirm a SPILLED vreg is actually reloaded multiple times in the
  loop-heavy fixtures (fib_loop/nestedloop/sieve) before building the staging-reg cache. Cheapest probe: a
  gitignored emit-instrumentation spike counting `gprLoadSpilled.spill` LDRs per vreg per basic-block (or
  disasm the hot fn). If a vreg reloads ≥2× within a block (no clobber between) → headroom exists → build the
  emit-side staging-reg cache (arm64 first per W54) → x86_64 → bench. If reloads are already minimal → revisit
  ADR-0149 (fold the small gain into §15.P aggregate).
- **Exit-condition**: EITHER ≥5% bench-delta on ≥3 loop-heavy fixtures + differential green (no miscompile) + a
  reload-elim unit test; OR (if measured headroom < target) an ADR amendment folding the gain into §15.P aggregate
  parity with the empirical data.

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

This turn: **§15.2 re-target** — structural read of `arm64/{emit,gpr}.zig` proved the slot-alias coalescer has
~0 headroom → ADR-0149 + ROADMAP §15.2/§15.3 re-scoped (slot-alias → redundant spill-reload elim). **DOCS/scope
only — NO src/ change → no ubuntu kick** (code HEAD `45a94348`, ubuntu-verified OK). **NOTE** (lesson
`gate-tail-vs-exit-code`): benign `failed command: …--listen=-` / `arm64/emit: failing op` next to a passing run
= error-path test noise — EXIT authoritative.

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
