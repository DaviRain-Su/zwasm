# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **11 IN-PROGRESS — WASI 0.1 full + bench infra** (Phase 10 = DONE 2026-06-03, `5ab7b981`; Wasm 3.0
  complete on both backends per ADR-0133). §11 task table open (11.0✓ / 11.1 WASI / 11.2 bench / 11.3 SIMD-gap /
  11.4 GC-rooting / 11.P).
- **§11.2 bench (in progress, `1c13e9f3`)**: un-stubbed `record_merge_bench.sh` — was a Phase-0-10 placeholder
  (appended `benches: []` comments); now a thin wrapper exec'ing the real `run_bench.sh` (hyperfine engine).
  Verified Mac: `--quick --bench=tinygo/arith` → real row (mean_ms=2.39). §12.4 cadence: Phase 0-13 = MANUAL
  recording (auto-CI `bench.yml` push-trigger DISABLED 2026-05-25 per user — do NOT re-enable). REMAINING for
  §11.2: (a) Linux row — run `record_merge_bench.sh --phase-record` ON ubuntunote (arch auto = x86_64-linux); a
  remote bench kick (analogous to `run_remote_ubuntu.sh`) or manual SSH; (b) Windows row → windowsmini, phase-
  boundary batch; (c) decide if a 3-host `--phase-record` lands real `history.yaml` rows at phase close (§11.P
  exit = "bench auto-record 3-host"). NOT a `gate_merge.sh` wiring — that would re-introduce the auto-bench the
  user disabled; manual per-merge is the §12.4 Phase-0-13 design.
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

## Next task (autonomous)

§11.2 Mac manual recorder is now real (`1c13e9f3`). Next: **§11.2 Linux row** — get a real `x86_64-linux`
`history.yaml` entry from ubuntunote. Either (a) a one-shot remote bench kick (SSH: sync repo → `nix develop ...
record_merge_bench.sh --quick --phase-record --reason='p11.2: linux baseline'` → pull the fragment), or (b) note
it as a phase-close batch alongside the windowsmini row. Heavy benches (e.g. shootout/fib2) take minutes each;
use the light subset for smoke (tinygo/arith ~2ms). Then **§11.3 SIMD gap** + §11.4 GC-rooting. Windows realworld
subset (last 11.1 line) + windowsmini bench row both go to the phase-boundary batch per the skip policy.

## Deferred / open debt (all blocked-by/note; none a Phase-11 blocker)

- **D-211** GC-on-JIT precise rooting → §11.4 (emit DONE; only rooting deferred, safe per non-moving+no-reclaim).
- **D-210** cross-module frame-consuming TC cohort stack-save (terminating programs correct; not a corpus gap).
- **D-238** x86_64 cross-instance EH thunk parity (arm64 done; FP-walk MOV + RBP variant).
- **D-234** memory64 OOB harness false-report (codegen proven correct 6 paths; runner-side fix).
- D-237 spec-runner double-free (harness); D-229/D-231 x86_64 follow-ons (note); D-204/D-209/D-213 (note).
- realworld GC/EH/TC producers (dart/hoot/wasm_of_ocaml/emscripten_eh — I21, toolchain provisioned).

## Step 0.7 (next resume)

`fcc9fe03` (D-243) was ubuntu-verified GREEN this cycle (Step 0.7 OK, all `fail=0`; ubuntunote even ran the
diff_runner — rust_file_io MATCHed on Linux too). THIS turn landed only `1c13e9f3` — a pure shell-orchestration
change (`record_merge_bench.sh` → wrapper); `zig build test-all` does NOT invoke it, so NO ubuntu kick (non-code
gap, like docs-only). Last ubuntu-verified HEAD = `fcc9fe03`. Next cycle Step 0.7 = nothing to verify (no kick
fired); proceed to §11.2 Linux row / §11.3.

**Gate hygiene**: Step-5 Mac gate = `bash scripts/mac_gate.sh`. JIT corpus: `zig build test-spec-wasm-3.0-assert`
(NO bogus `-Dno-run`); pick the exe by mtime (bare `head -1` = STALE). `ZWASM_SPEC_ENGINE=jit <exe>
test/spec/wasm-3.0-assert --fail-detail >out 2>err` (SPLIT stderr).

## Key refs

- ROADMAP §11 (WASI 0.1 + bench + SIMD gap + GC-rooting). ADR-0128 (Phase 10); ADR-0133 (§10 re-scoped exit);
  ADR-0067 (3-host bench). `debug_jit_auto` skill for JIT dispatch fails.
- Lessons (this session): `2026-06-03-callstackexhausted-diagnose-runaway-vs-deep` (D-242, now RESOLVED),
  `2026-06-03-sanity-check-must-share-the-real-gates-constant` (D-241),
  `2026-06-03-reprobe-blocked-by-barriers-before-scoping` (D-240 + D-210).
