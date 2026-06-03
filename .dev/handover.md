# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **12 IN-PROGRESS — AOT compilation mode** (Phase 11 DONE 2026-06-03; widget advanced). Phase 11 =
  WASI 0.1 full + bench infra + SIMD gap profile, closed at `bbc4900b` with the 3-host `test-all` reconcile GREEN.
- **§11 close**: §11.1 (WASI, incl. Windows realworld subset) / §11.2 (bench, Mac+Linux) / §11.3 (SIMD gap ✓) /
  §11.P all `[x]`. §11.4 → Phase 15 (ADR-0135). **Bench re-scoped to 2-host** (Mac+Linux) per **ADR-0137**:
  hyperfine absent on windowsmini (native zig.exe, no nix shell; not autonomously provisionable) → Windows bench
  *timing* deferred to **D-249** (correctness reconcile unaffected).
- **11.P-win64-jit bundle CLOSED** (`bbc4900b`, windowsmini run-2 GREEN — zero crashes across 50131 lines): the
  §11.P windowsmini reconcile surfaced Phase-10 EH/GC-on-JIT bugs on the Win64 ABI (first Win64 run since §11.1).
  Fixed + verified: (1) 15 GC/EH emit files hardcoded SysV arg regs → `abi.current.arg_gprs[]` (cycle-1, ≤4-arg);
  (2) 6 ≥5-arg array ops → `gc_marshal.routeArg` stack-spill + `computeOutgoingMaxBytes` Win64 shadow/stack
  reservation (cycle-2, ex-D-248); (3) throw_trampoline Win64 test-wrapper RSP 16-byte parity (`subq/addq $8`).
  All SysV-no-op (Mac+ubuntu green throughout). Lesson:
  `2026-06-03-win64-jit-trampoline-arg-marshal-hardcoded-sysv`.
- **3-host invariant RESTORED**: Mac aarch64 + ubuntunote x86_64-SysV + windowsmini x86_64-Win64 all GREEN.

## Active bundle

- **Bundle-ID**: 12.1-aot-cwasm-loader
- **Cycles-remaining**: ~1 (loader CORE + §12.2 + v0.2 format-layer + producer wiring DONE; remaining = `zwasm
  run *.cwasm` CLI branch + its standalone-runtime design, then §12.1 `[x]`)
- **Continuity-memo**: survey → `private/notes/p12-12.1-aot-loader-survey.md`. **DONE**: loader CORE
  (`ca69fc68`,`50b4bd1a`); §12.2 differential `[x]` (`bd138990`,`d0c1281e`); ADR-0138 entry-point design;
  v0.2 format-layer `926bed9f` (`.cwasm` v0.2 exports section, header 60→68B, `format`/`serialise`/`load` +
  `LoadedModule.resolveEntry(invoke_name)` = `_start`→`main`→first-export, returns DEFINED idx); **producer
  wiring `e090562d`** — `runner.CompiledWasm.exports` (func-kind, arena-owned via `collectFuncExports` in
  compile.zig, both return sites), `produceFromCompiledWasm` maps → `serialise.Input.exports`; verified by a
  runner_test that a `compileWasm`→produce→`load` `.cwasm` has `resolveEntry("f")==0` + executes. **NEXT (CLI
  branch — needs the standalone-runtime sub-design)**: `cli/run.zig` (Zone 3) `.cwasm` branch → `aot_load.load`
  → `resolveEntry(invoke_name)` → invoke. **The wrinkle**: the loaded entry is `callconv(.c) fn(*JitRuntime)…`
  but we have no `compiled`/`wasm_bytes` to build the runtime via `setupRuntime`. (a) For the STATELESS subset
  (no memory/globals/imports — e.g. a `()→i32` compute export) a minimal `JitRuntime` (stack struct, dummy
  bases, zero counts; prologue only stores `jit_executed_flag` into the struct itself) suffices — put this in a
  Zone-2 helper (`aot/run.zig`) to keep JIT-ABI knowledge out of Zone 3. (b) Result surfacing needs the entry's
  result type — loader currently drops sig; either expose `LoadedModule` entry sig (parse types section) or
  invoke `--invoke <name>` as i32→exit-code. (c) STATEFUL `.cwasm` (memory/globals/imports) reconstruction is
  genuinely later scope — the format carries no memory/global/data sections → file a D-NNN debt row when the CLI
  lands. End-to-end test: `zwasm run --invoke f prog.cwasm` → exit code = the i32 result.
- **Exit-condition**: §12.1 `[x]` when `zwasm run *.cwasm` runs a real (stateless-MVP) artefact end-to-end via
  the CLI; stateful runtime reconstruction tracked as debt.

## Next task (autonomous)

Phase 12 (AOT) IN-PROGRESS. §12.2 `[x]`; v0.2 format-layer (`926bed9f`) + producer exports wiring (`e090562d`)
landed + green. **NEXT** = `cli/run.zig` `.cwasm` branch: a Zone-2 `aot/run.zig` helper builds a minimal
stateless `JitRuntime`, invokes the `resolveEntry`-selected loaded entry, surfaces the i32 result as exit code;
`run.zig` detects the `.cwasm` magic/extension and routes there. File a debt row for stateful (memory/globals/
imports) `.cwasm` runtime reconstruction. §12.1 `[x]` closes on the end-to-end `zwasm run --invoke f *.cwasm` test.

## Deferred / open debt (none a Phase-12 blocker)

- **D-249** Windows bench timing (hyperfine on windowsmini / native path) — perf-completeness only, ADR-0137.
- **D-245** host→JIT callee-saved: arm64 + x86_64-SysV no-arg-void fixed; win64 + arg'd variants = remainder.
- **D-246** §11.3 arm64 dot/extmul JIT-emit hole → Phase 15. **D-211** GC-on-JIT precise rooting → Phase 15.
- **D-238** x86_64-SysV cross-instance EH thunk. **D-244** SIMD interp-free (partial). D-210/D-234/D-237/D-229/
  D-231/D-204/D-209/D-213 (note).

## Step 0.7 (next resume)

This turn landed v0.2 format-layer (`926bed9f`) + producer exports wiring (`e090562d`); Mac test+lint+zone green.
Prior ubuntu verified `63b2cd24` OK. An ubuntu `test` is kicked against this turn's final HEAD (`e090562d`) →
next resume `tail /tmp/ubuntu.log` for OK. Phase-12 code is Mac+ubuntu only (exec/differential tests skip Win64
via `skip.phaseEnd`; the v0.2 `resolveEntry`-precedence test runs on all hosts; windowsmini = phase-boundary).

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile: `zig build test
-Dtarget=x86_64-windows-gnu` (compile-only; run-error = compile passed). 3-host reconcile = phase boundary.

## Key refs

- ROADMAP §12 (AOT — Goal + exit criteria at line ~1432); Phase Status widget (Phase 11 DONE / 12 IN-PROGRESS).
- ADR-0137 (Windows bench re-scope); ADR-0040/0039 (AOT substrate from §9.8b); ADR-0117 (GC stack-map for AOT).
- Lessons: `2026-06-03-win64-jit-trampoline-arg-marshal-hardcoded-sysv`, `2026-06-03-windowsmini-reconciliation-
  catches-os-only-compile-drift`, `2026-06-03-host-to-jit-must-preserve-callee-saved`.
