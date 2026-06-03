# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **12 IN-PROGRESS — AOT compilation mode**. §12.0/§12.1/§12.2/§12.3/§12.3b `[x]`; next `[ ]` = §12.4
  (cold-start bench). Phase 11 DONE. §12.5 (stack-map) Phase-15-coupled (ADR-0139). §12.P close after §12.4.
- **§12.3b stateful `.cwasm` — COMPUTE subset DONE + bundle CLOSED** (ADR-0140). `.cwasm` v0.3 serialises +
  reconstructs module state from the artefact alone: globals (`797a7ef0`), memory + data segments (`58e97a09`),
  table 0 + element segments / `call_indirect` (`9b416428`). Delta: real memory/globals/table compute modules
  run AOT — **all 12 SIMD corpus fixtures `zwasm compile`+`run` to exit 0** (verified `cf32e57a`). v0.3 header
  104 B; per-section pattern (offset/size pairs + flag bits) mirrors the exports section. `aot/run.runEntry`
  reconstructs: `globals_base`/`vm_base`+`mem_limit` (alloc+memcpy, freed after call)/`funcptr_base`+
  `table_size`+`typeidx_base` (built at load from func_offsets + canon_typeidx).
- **WASI/host imports DEFERRED (ADR-0140 / D-251)**: `--engine=jit` is itself compute-only (no WASI, ADR-0136/
  D-244) — AOT-WASI lands WITH the JIT-WASI d-3 work, no parity gap. WASI-importing fixtures (shootout `proc_exit`,
  tinygo `fd_write`) run on NEITHER path today; so §12.4 bench re-scoped to compute (zero-import) fixtures.

## Next task (autonomous)

§12.4 — cold-start bench-delta: AOT (`zwasm run prog.cwasm` = load+reloc+first-call) vs JIT (`zwasm run
--engine=jit prog.wasm` = compile+first-call) **≥30%** improvement on ≥3 **compute (zero-import)** fixtures (the
SIMD corpus `bench/runners/wasm/simd/*.wasm` runs AOT today; pick ≥3). Step 0 survey: `scripts/run_bench.sh` (the
hyperfine harness + `bench/results/history.yaml` schema), how to express the two commands as a hyperfine
comparison, and whether `--engine=jit` runs the SIMD `_start` (the cli/run.zig `simd_start` test says yes). Bench
2-host Mac+Linux (ADR-0137). Record the delta; threshold ≥30% (cold-start estimate `p8-8b3-aot-survey.md`). Then
§12.5 stack-map (Phase-15-coupled — likely a thin reserved section or defer) + §12.P close.

## Deferred / open debt (none a Phase-12 blocker)

- **D-251** WASI/host imports in AOT standalone runtime — deferred to land with JIT-WASI (D-244 d-3); no parity
  gap (both compute-only). ADR-0140.
- **D-249** Windows bench timing (hyperfine on windowsmini) — perf-completeness only, ADR-0137.
- **D-245** host→JIT callee-saved: arm64 + x86_64-SysV no-arg-void fixed; win64 + arg'd variants = remainder.
- **D-246** §11.3 arm64 dot/extmul JIT-emit hole → Phase 15. **D-211** GC-on-JIT precise rooting → Phase 15.
- **D-238** x86_64-SysV cross-instance EH thunk. **D-244** SIMD interp-free (partial) + JIT-WASI d-3.
  D-210/D-234/D-237/D-229/D-231/D-204/D-209/D-213 (note).

## Step 0.7 (next resume)

This turn = §12.3b re-scope + bundle close (ADR-0140) + cycle-2a was verified ubuntu `cf32e57a` OK. No new
`src/` code this turn (ADR + ROADMAP + debt + handover only) → NO ubuntu kick owed; last code HEAD `cf32e57a`
verified. Next resume: start §12.4 bench (no ubuntu pending). Phase-12 exec tests skip Win64 via `skip.phaseEnd`;
windowsmini = phase-boundary.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile: `zig build test
-Dtarget=x86_64-windows-gnu` (compile-only). 3-host reconcile = phase boundary.

## Key refs

- ROADMAP §12 (Goal + exit ~line 1432; §12.4/12.5/12.P rows); Phase Status widget.
- ADR-0140 (WASI-in-AOT defer + §12.4 compute-scope + 12.3b close); ADR-0139 (Phase-12 re-sequence); ADR-0138
  (`.cwasm` v0.2 exports); ADR-0040/0039 (AOT substrate); ADR-0137 (bench 2-host); ADR-0136 (`--engine=jit`).
- `scripts/run_bench.sh` + `bench/` = the §12.4 harness. `p8-8b3-aot-survey.md` = cold-start estimate.
