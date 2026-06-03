# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Active bundle

- **Bundle-ID**: 15.1-gc-reclamation (GC reclamation + precise rooting — correctness-critical, non-moving)
- **Cycles-remaining**: ~4–6 (native-stack scan → free-list reclaim → tests)
- **Continuity-memo**: **Step-0 survey DONE → `private/notes/p15-gc-survey.md`.** Collector = non-moving
  mark-sweep, sweep `collector_mark_sweep.zig:214` never frees; rooting today = conservative INTERP walk
  (`walkRootsImpl` :243) — complete for interp, but does NOT scan native JIT frames, and GC-on-JIT emits allocs
  (§10.G) → reclamation UNSAFE until a conservative native-stack scan covers JIT roots (ADR-0128 §2; NON-moving
  needs only conservative scan, NOT precise GcRootMap-emit). **SAFE incremental order**: (1) conservative
  native-stack scan rooting [strictly ADDS roots → can't cause UAF, only prevent; reuse `platform/stack_limit.zig`
  for stack bounds] → (2) free-list reuse in sweep, gated behind (1). Files: collector_mark_sweep.zig, heap.zig
  (free_lists), object_alloc.zig, root_scope.zig. ADR-0135 = rooting↔reclaim couple; no-reclaim safe interim.
- **PROGRESS**: chunk **1a DONE** `5de51a69` — `stack_limit.nativeStackHigh()`. Chunk 1b (scan) ATTEMPTED +
  REVERTED — surfaced **TWO correctness findings that reshape the design**:
  1. **markFromRoot CORRUPTS on non-object-start refs** (`collector_mark_sweep.zig:146-147` unconditionally
     sets bit31 + writes back; `:149` switches on the `ObjectKind` byte). A conservative stack scan reports
     INTERIOR + garbage offsets, not just object starts → marking one sets bit31 of *payload* data (corruption)
     + can PANIC on a corrupt enum byte. ⇒ chunk 1b MUST validate **object-start-ness** before marking: build an
     object-start SET/bitmap (one heap walk like `runCollection` does — start at min_align, decode size via
     `objectSizeAt`, advance), then mark a stack candidate only if its offset ∈ the set (then markFromRoot
     traces transitively, safe). Check full-word AND low-32 candidates; flag-gated default-FALSE.
  2. **GC `collect()` is NEVER triggered in production** — `heap.allocate` just bumps/`growTo` (no auto-collect);
     the collector is TEST-ONLY. So §15.1's full scope also needs a **heap-pressure collection trigger** (allocate
     hits a threshold / can't grow → collect → reclaim → retry) — that trigger site is where `scan_native_stack`
     gets opted-in. Bigger than just free-list reuse.
  **NEXT chunk 1b (redo, correct)**: object-start-validated conservative scan in walkRootsImpl (scan runs BEFORE
  the `runtime orelse return` so it's runtime-independent). Test: stack-held GcRef marked with-flag vs not without.
- **Exit-condition**: free-list reuse + heap-pressure collect trigger land + an alloc-loop test shows `heap.cursor`
  BOUNDED (vs unbounded leak today) + all existing GC unit/spec tests green.

## Current state

- **Phase 15 (Performance parity with v1 + ClojureWasm) IN-PROGRESS.** Phase 14 (CI matrix) DONE
  (ADR-0145). Phase 13 (C API) DONE (ADR-0144). Phase 12 (AOT) DONE.
- **Phase 14 recap**: CI workflows (`pr`/`bench`/`bench_baseline`/`nightly`.yml — all workflow_dispatch,
  actionlint-clean, §14.5 CI-second-line) + fuzz infra (`test/fuzz/` parse/validate/instantiate crash-harness
  in test-all + the nightly smith campaign + proposal-watch + spec-bump legs). §14.P **re-scoped past D-245
  win64** (ADR-0145, same as §13.P/ADR-0144): deliverables 3-host-green (test-fuzz `0 crashes` on Mac+ubuntu+win),
  windows sole-failure = the D-245 carry. audit_scaffolding 0-block (`private/audit-2026-06-04-p14close.md`).

## Next task (autonomous)

**Work the 15.1-gc-reclamation bundle (above).** Chunk 1a done; **NEXT = chunk 1b REDO** — the
object-start-VALIDATED conservative scan (the naive scan corrupts payload + panics; see the bundle PROGRESS
findings for the object-start-set recipe). Build the start-set, gate the scan behind `scan_native_stack` (default
false), test stack-held-ref-marked-with-flag-vs-not. Then chunk 1c = heap-pressure collect trigger + chunk 2 =
free-list reuse. **Correctness-critical — don't rush.** After §15.1: §15.2 coalescer → §15.3 class-aware → §15.4
SIMD → **§15.5 D-245 win64** (hard/remote) → §15.6 ClojureWasm. (D-257 lesson half `partial`, not blocking.)

## Step 0.7 (next resume)

This turn: §15.1 chunk-1b investigation — attempted the scan, found the markFromRoot-corrupts-on-interior +
no-production-collect-trigger issues (bundle PROGRESS), REVERTED the incorrect scan (kept correct 1a). Prior
chunk 1a (`5de51a69`) ubuntu test-all **OK** (verified). DOCS only this turn (handover) → no ubuntu kick (code
HEAD `5de51a69` verified). **NOTE** (lesson `gate-tail-vs-exit-code`): benign `failed command: …--listen=-` /
`arm64/emit: failing op` next to a passing run = error-path test noise, not a failure.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile = `zig build test
-Dtarget=x86_64-windows-gnu`. windowsmini exec = `run_remote_windows.sh` (phase boundary).

## Deferred / open debt

- **D-257** (NOW) 20-marker `<backfill>` cohort — discharge this resume. **D-245** win64 host→JIT = §15.5
  (windows-CI/bench-green; hard remote asm). **D-255** C-API WASI io-infra (ADR-0143). **D-254** rust 3-OS
  (ADR-0142). **D-253** §13.2 host_info (cap). **D-251** WASI in AOT. **D-249** win bench timing (ADR-0137).
  **D-246** arm64 dot/extmul = §15.4. **D-238** x86_64 EH thunk. D-210/D-234/D-237/D-229/D-231/D-204/D-209/D-213.

## Key refs

- ROADMAP §15 task table (just expanded; 15.1 GC … 15.5 D-245 … 15.6 ClojureWasm). Phase Status widget
  (14 DONE / 15 IN-PROGRESS). ADR-0145 (§14.P close, re-scope-past-D-245); ADR-0135/0115/0128 (GC); ADR-0141 (§12.5).
