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
- **Cycles-remaining**: ~1 (format-layer v0.2 DONE; remaining = producer-side exports wiring + `zwasm run
  *.cwasm` CLI branch, then §12.1 `[x]`)
- **Continuity-memo**: Step 0 survey → `private/notes/p12-12.1-aot-loader-survey.md`. **Loader CORE DONE**:
  `load.zig` `load()` (parseHeader → arch-check → alloc+memcpy code → parse metas → `applyRelocs` →
  setExecutable → `entry(idx, Fn)`), single-func (`ca69fc68`), 2-func reloc (`50b4bd1a`). **§12.2 differential
  `[x]`** (`bd138990`,`d0c1281e`): JIT vs AOT equal across i32/i64 const + internal-call reloc through the real
  pipeline. **ENTRY-POINT DESIGN DONE (ADR-0138)** → **v0.2 format-layer landed `926bed9f`**: `.cwasm` v0.2 adds
  an exports section (header 60→68B: `exports_offset`+`exports_size`; section = `[n_exports][name_len,name,
  func_idx]…`, func-kind only). `format.zig` (writeExportEntry/parseExportEntry, version_v0_2), `serialise.zig`
  (Input.exports, writes section), `load.zig` (parses+dups names into `LoadedModule.exports`, adds
  `resolveEntry(invoke_name)` mirroring run.zig's `_start`→`main`→first-export precedence, returns DEFINED idx).
  Unit tests green (round-trip + resolveEntry precedence + exec). **NEXT (producer wiring + CLI)**: (1)
  `runner.CompiledWasm` doesn't carry exports — thread the wasm export table (func-kind) from `compileWasm`
  through `produce.produceFromCompiledWasm` into `serialise.Input.exports`; (2) `cli/run.zig` `.cwasm` branch:
  detect extension/magic → `load` → `resolveEntry(invoke_name)` → invoke (start with void `_start` via the
  loaded entry, matching `runVoidExport`'s ABI). Then §12.1 `[x]` + end-to-end CLI test.
- **Exit-condition**: §12.1 `[x]` when `zwasm run *.cwasm` runs a real artefact end-to-end (loader CORE +
  §12.2 + v0.2 format-layer met; the bundle closes at the producer-wiring + CLI branch).

## Next task (autonomous)

Phase 12 (AOT) IN-PROGRESS. §12.2 `[x]`. ENTRY-POINT design decided (ADR-0138: `.cwasm` v0.2 exports section)
+ **format-layer landed `926bed9f`** (format/serialise/load + `resolveEntry`, unit-tested). **NEXT** = wire the
producer side: carry func-kind exports from `compileWasm`/`CompiledWasm` → `produceFromCompiledWasm` →
`serialise.Input.exports`; then the `cli/run.zig` `.cwasm` branch (`load` → `resolveEntry` → invoke). §12.1 row
`[x]` closes on the end-to-end `zwasm run *.cwasm` test.

## Deferred / open debt (none a Phase-12 blocker)

- **D-249** Windows bench timing (hyperfine on windowsmini / native path) — perf-completeness only, ADR-0137.
- **D-245** host→JIT callee-saved: arm64 + x86_64-SysV no-arg-void fixed; win64 + arg'd variants = remainder.
- **D-246** §11.3 arm64 dot/extmul JIT-emit hole → Phase 15. **D-211** GC-on-JIT precise rooting → Phase 15.
- **D-238** x86_64-SysV cross-instance EH thunk. **D-244** SIMD interp-free (partial). D-210/D-234/D-237/D-229/
  D-231/D-204/D-209/D-213 (note).

## Step 0.7 (next resume)

This turn landed §12.2 broadening (`d0c1281e`) + v0.2 format-layer (`926bed9f`); Mac test+lint+zone green. A
prior terminal crash interrupted the gate but work was intact + re-verified on resume. `/tmp/ubuntu.log` was
absent (machine cycled; not a FAIL) — last verified ubuntu = `a091d0a7` OK. An ubuntu `test` is kicked against
this turn's final HEAD → next resume `tail /tmp/ubuntu.log` for OK. Phase-12 code is Mac+ubuntu only (exec /
differential tests skip Win64 via `skip.phaseEnd`; the v0.2 `resolveEntry`-precedence test runs on all hosts;
windowsmini = phase-boundary).

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile: `zig build test
-Dtarget=x86_64-windows-gnu` (compile-only; run-error = compile passed). 3-host reconcile = phase boundary.

## Key refs

- ROADMAP §12 (AOT — Goal + exit criteria at line ~1432); Phase Status widget (Phase 11 DONE / 12 IN-PROGRESS).
- ADR-0137 (Windows bench re-scope); ADR-0040/0039 (AOT substrate from §9.8b); ADR-0117 (GC stack-map for AOT).
- Lessons: `2026-06-03-win64-jit-trampoline-arg-marshal-hardcoded-sysv`, `2026-06-03-windowsmini-reconciliation-
  catches-os-only-compile-drift`, `2026-06-03-host-to-jit-must-preserve-callee-saved`.
