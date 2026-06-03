# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **11 IN-PROGRESS — WASI 0.1 full + bench infra** (Phase 10 = DONE 2026-06-03, `5ab7b981`; Wasm 3.0
  complete on both backends per ADR-0133). §11 task table open (11.0✓ / 11.1 WASI / 11.2 bench / 11.3 SIMD-gap /
  11.4 GC-rooting / 11.P).
- **§11.2 bench (paths verified, `1c13e9f3`+`d303f427`)**: `record_merge_bench.sh` un-stubbed → thin wrapper over
  the real `run_bench.sh` hyperfine engine (Mac: `--quick --bench=tinygo/arith` → mean_ms=2.39). `run_remote_ubuntu.sh`
  gained a `bench` step (runs the recorder under the remote nix shell; hyperfine 1.20.0 confirmed on ubuntunote) →
  Linux row path verified (`bench --quick --bench=tinygo/arith` wrote a real x86_64-linux recent.yaml row).
  §12.4 cadence: Phase 0-13 = MANUAL recording; auto-CI `bench.yml` push-trigger DISABLED 2026-05-25 per user —
  do NOT re-enable, do NOT wire `gate_merge.sh`. REMAINING (phase-close batch): committed 3-host `--phase-record`
  baseline rows into `history.yaml` (Mac local + Linux via `append_bench_to_history.sh` fragment extract/append +
  windowsmini) — §11.P exit "bench auto-record 3-host". Use `--windows-subset` (5 light benches) for fast runs;
  heavy benches (fib2) take minutes each.
- **LAST code HEAD** (`89aaebcf`): **D-243 RESOLVED** — the realworld DIFF runner now preopens a fresh scratch
  `--dir` (guest ".") for needs-preopen fixtures on BOTH sides (wasmtime `--dir <scratch>::.` + v2
  `runWasmCapturedOpts`). `rust_file_io.wasm` flips SKIP-V2-TRAP → **MATCH** (`zig build test-realworld-diff` =
  50/55 matched, 0 mismatched, 0 skipped-v2). Prior `7806936f`: **D-242 RESOLVED** — per-frame label stack spills
  to a lazy heap overflow (`max_label_stack` = `zir.max_control_stack`, was a stale 128 < validator 1024); all 9
  `go_*` exit 0, `test-realworld-run` 55/55, 0 SKIP-WASI. **§11.1 WASI capability + gate-visibility = DONE on Mac;
  only the Windows realworld subset (25 samples, windowsmini) remains, deferred to the phase-boundary batch.**
- **JIT corpus final** (`dbcfff1b`, ubuntu-verified `eba86890`): memory64 336/1(D-234)/0, tail-call 71/0/0, EH
  34/0/0, gc 402/0/5, function-references 36/0/3, multi-memory 0/0/407(→§14). Spec corpus = interp default; JIT
  opt-in `ZWASM_SPEC_ENGINE=jit`.
- **GATE TRAP** (still live): JIT corpus exe MUST be picked by mtime (`find … -exec ls -t {} + | head -1`); bare
  `head -1` = STALE binary → masks the delta.
- **Watch**: `runner_test.zig` ~1490 / `runner_gc_test.zig` 1499 / `jit_abi.zig` 1364 / `validator.zig` 3267 (cap
  3300, D-204) — all < hard.

## Active bundle

- **Bundle-ID**: 11.3-simd-gap (D-074 cohort)
- **Cycles-remaining**: ~2
- **Continuity-memo**: §11.3 SIMD per-op gap analysis = v2 vs **median of (wasmtime, wazero, wasmer)**, flag ops
  lagging >3×, file Phase-15 debt. DONE: ch1 (`e6dd3f94`) wazero+wasmer in flake; ch2 (`843cc7de`)
  `run_bench.sh --compare={wazero,wasmer,all}` (all 4 switch-sites) + `pkgs.git` in flake (macOS /usr/bin/git is
  an xcrun shim that dies under `nix develop`, where the gap run must execute). Verified: `nix develop --command
  bash -c 'run_bench.sh --quick --bench=tinygo/arith --compare=all'` records 4 runtime rows, exit 0.
  NEXT (ch3): a per-op **SIMD micro-bench corpus** — small `.wasm` fixtures each hammering one SIMD op class
  (i32x4 add/mul, f32x4 ops, shuffles, swizzle, dot, extmul, narrow, etc.) under `bench/runners/wasm/simd/`,
  generated Mac-only via `nix develop .#gen` (wat2wasm). Then ch4: a gap-analysis script that parses the
  multi-runtime `recent.yaml`, computes per-op `zwasm_mean / median(wasmtime,wazero,wasmer)`, flags >3×, and files
  Phase-15 debt rows naming the candidate opt (AVX/CPUID, MOVAPS peephole, SIMD coalescing per §9.10 Track A).
- **Exit-condition**: a `--compare=all` gap run over the SIMD corpus emits a per-op zwasm/median ratio table +
  Phase-15 debt entries for every op > 3×; `run_bench.sh --quick` still works locally.

§11.1/§11.2 phase-close-batch items (Windows realworld subset + windowsmini bench row + committed 3-host bench
rows) remain for §11.P. §11.4 moved to Phase 15 (ADR-0135).

## Deferred / open debt (all blocked-by/note; none a Phase-11 blocker)

- **D-211** GC-on-JIT precise rooting → **Phase 15** (ADR-0135; paired with reclamation; emit DONE, rooting safe
  to defer per non-moving+no-reclaim). Residual: no struct/array/ref_cast JIT op-emit file (interp-only) — noted.
- **D-210** cross-module frame-consuming TC cohort stack-save (terminating programs correct; not a corpus gap).
- **D-238** x86_64 cross-instance EH thunk parity (arm64 done; FP-walk MOV + RBP variant).
- **D-234** memory64 OOB harness false-report (codegen proven correct 6 paths; runner-side fix).
- D-237 spec-runner double-free (harness); D-229/D-231 x86_64 follow-ons (note); D-204/D-209/D-213 (note).
- realworld GC/EH/TC producers (dart/hoot/wasm_of_ocaml/emscripten_eh — I21, toolchain provisioned).

## Step 0.7 (next resume)

Last ubuntu-verified CODE HEAD = `fcc9fe03` (D-243, all `fail=0`). Since then only shell/docs/ADR/flake commits
(…`e6dd3f94` flake comparators, `843cc7de` --compare wiring + flake git) — none touch src/test, so NO ubuntu
test-all kick (non-code gap). The flake.nix change (wazero/wasmer/git) rebuilds the dev shell on next remote
`nix develop`; verify implicitly on the next remote bench run. Next cycle Step 0.7 = nothing to verify.

**Gate hygiene**: Step-5 Mac gate = `bash scripts/mac_gate.sh`. JIT corpus: `zig build test-spec-wasm-3.0-assert`
(NO bogus `-Dno-run`); pick the exe by mtime (bare `head -1` = STALE). `ZWASM_SPEC_ENGINE=jit <exe>
test/spec/wasm-3.0-assert --fail-detail >out 2>err` (SPLIT stderr).

## Key refs

- ROADMAP §11 (WASI 0.1 + bench + SIMD gap + GC-rooting). ADR-0128 (Phase 10); ADR-0133 (§10 re-scoped exit);
  ADR-0067 (3-host bench). `debug_jit_auto` skill for JIT dispatch fails.
- Lessons (this session): `2026-06-03-callstackexhausted-diagnose-runaway-vs-deep` (D-242, now RESOLVED),
  `2026-06-03-sanity-check-must-share-the-real-gates-constant` (D-241),
  `2026-06-03-reprobe-blocked-by-barriers-before-scoping` (D-240 + D-210).
