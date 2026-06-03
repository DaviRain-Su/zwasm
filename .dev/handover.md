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
- **Exit-condition**: free-list reuse lands + an interp alloc-loop test shows `heap.cursor` BOUNDED (vs unbounded
  leak today) + all existing GC unit/spec tests green. First red test: native-stack-held GcRef survives collection.

## Current state

- **Phase 15 (Performance parity with v1 + ClojureWasm) IN-PROGRESS.** Phase 14 (CI matrix) DONE
  (ADR-0145). Phase 13 (C API) DONE (ADR-0144). Phase 12 (AOT) DONE.
- **Phase 14 recap**: CI workflows (`pr`/`bench`/`bench_baseline`/`nightly`.yml — all workflow_dispatch,
  actionlint-clean, §14.5 CI-second-line) + fuzz infra (`test/fuzz/` parse/validate/instantiate crash-harness
  in test-all + the nightly smith campaign + proposal-watch + spec-bump legs). §14.P **re-scoped past D-245
  win64** (ADR-0145, same as §13.P/ADR-0144): deliverables 3-host-green (test-fuzz `0 crashes` on Mac+ubuntu+win),
  windows sole-failure = the D-245 carry. audit_scaffolding 0-block (`private/audit-2026-06-04-p14close.md`).

## Next task (autonomous)

**Work the 15.1-gc-reclamation bundle (above).** Survey done; **chunk 1 = the conservative native-stack scan**
(the strictly-safe rooting prerequisite). Step 0: read `platform/stack_limit.zig` (stack-bound infra to reuse) +
`collector_mark_sweep.zig walkRootsImpl` + how GC is triggered (alloc-time). Red test: an asm/native-stack-held
GcRef is in the MARK set after collection. Then chunk 2 = free-list reuse (gated). **Correctness-critical — don't
rush** (a missed root → UAF heisenbug once reclaim is on). Then §15.2 coalescer → §15.3 class-aware → §15.4 SIMD
→ **§15.5 D-245 win64** (hard/remote; deliberate session) → §15.6 ClojureWasm. (D-257 lesson-Citing half is
`partial`, not blocking.)

## Step 0.7 (next resume)

This turn: D-257 ADR SHA-backfill (9 rows, `2893ab5e`) + D-257 → soon — DOCS only, no code → no ubuntu kick
(HEAD code `011dca7e` ubuntu-verified). **windowsmini reconcile (Phase-14 close) = `[run_remote_windows] OK`
GREEN** (seed `0x75fe1ff4` dodged D-245; the only `failed command: …--listen=-` lines are benign unit-test-
isolation noise, lesson `gate-tail-vs-exit-code`). §14 close fully verified 3-host. Next code change → ubuntu kick.

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
