# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **11 IN-PROGRESS — WASI 0.1 full + bench infra** (Phase 10 = DONE 2026-06-03, `5ab7b981`; Wasm 3.0
  complete on both backends per ADR-0133). §11 task table open (11.0✓ / 11.1 WASI / 11.2 bench / 11.3 SIMD-gap /
  11.4 GC-rooting / 11.P).
- **LAST code HEAD** (`bca625f2`): §11.1 file-I/O bundle **CLOSED** — fd_write/fd_read to file fds
  (std.Io.File.writeStreamingAll / readStreaming; EOF = error.EndOfStream → nread=0). **`zwasm run --dir <tmp>:.
  rust_file_io.wasm` now runs the full create+write+read+unlink flow and exits 0** (was trap). Bundle = cycle 1
  (--dir preopen + path_open O_CREAT, `0b4706b3`) + cycle 2 (file read/write, `bca625f2`); fd-roundtrip regression
  test. rust_file_io is a CAPABILITY pass; gate-visible PASS needs runner --dir wiring (D-243 remainder). Prior:
  fd_filestat_get/path_unlink_file (`b6224bbb`), D-241 verifier-drift fix (`142f0a53`), fd_prestat (`237f0313`).
- **JIT corpus final** (`dbcfff1b`, ubuntu-verified `eba86890`): memory64 336/1(D-234 harness)/0, tail-call
  71/0/0, EH 34/0/0, gc 402/0/5, function-references 36/0/3, multi-memory 0/0/407(→§14). All skips = eligibility-
  gate; all 59 modrej = multi-memory. Spec corpus = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`.
- **GATE TRAP** (still live): JIT corpus exe MUST be picked by mtime (`find … -exec ls -t {} + | head -1`); bare
  `head -1` = STALE binary → masks the delta.
- **Watch**: `runner_test.zig` ~1490 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 / `validator.zig` 3204 (cap 3300, D-204) — all < hard 2000/3300.

## Active bundle

- **Bundle-ID**: 11.1-label-stack (D-242)
- **Cycles-remaining**: ~1-2
- **Continuity-memo**: ROOT CAUSE FOUND + PROVEN this turn (no code) — go_* trap is `frame.pushLabel` overflowing
  the per-frame LABEL stack `max_label_stack = 128 < validator max_control_stack = 1024` (D-241 drift family; the
  "call stack exhausted" msg is shared by StackOverflow+CallStackExhausted, which mis-led 2 prior diagnoses).
  Raising max_label_stack → 1024 makes go_math_big exit 0 (verified). But `label_buf [N]Label` is INLINE in Frame
  → naive [1024] = ~5MB Runtime + 8x per-call copy + a stack-allocated 2-Runtime test SEGFAULTs. FIX = hybrid:
  keep `label_buf [128]` inline + a LAZY `label_overflow: []Label` (alloc on crossing 128, cap = zir.max_control_stack,
  free at popFrame). pushLabel needs an allocator → thread it through the 7 `.pushLabel(` sites (interp handlers
  have `rt`); popLabel/labelAt branch inline-vs-overflow; free-once at popFrame (mind the Frame value-copy).
- **Exit-condition**: `zwasm run go_math_big.wasm` exits 0 AND the full `zig build test` is green (no 5MB-Runtime
  segfault) AND no per-call regression for shallow funcs (label_overflow stays unallocated when label_len ≤ 128).

Other §11 tracks: 11.2 bench (substantially built — run_bench.sh --quick / history.yaml / record scripts; assess
what's left), 11.4 GC-on-JIT rooting (D-211). More preview1 syscalls = completeness only (0 SKIP-WASI remain).

§10 close-hygiene RESOLVED (SHA traceability via `5ab7b981` + phase_log; windowsmini DEFERRED per policy).

## Deferred / open debt (all blocked-by/note; none a Phase-11 blocker yet)

- **D-211** GC-on-JIT precise rooting → §11.4 (emit DONE; only rooting deferred, safe per non-moving+no-reclaim).
- **D-210** cross-module frame-consuming TC cohort stack-save (terminating programs correct; not a corpus gap).
- **D-238** x86_64 cross-instance EH thunk parity (arm64 done; FP-walk MOV + RBP variant).
- **D-234** memory64 OOB harness false-report (codegen proven correct 6 paths; runner-side fix).
- **D-242** interp 256-frame call stack too shallow for standard-Go runtime (go_* CallStackExhausted; §11.1 above).
- **D-243** no preopen-sandbox wiring for file-I/O fixtures (rust_file_io instantiates but can't open files; §11.1).
- D-237 spec-runner double-free (harness); D-229/D-231 x86_64 follow-ons (note); D-204/D-209/D-213 (note).
- realworld GC/EH/TC producers (dart/hoot/wasm_of_ocaml/emscripten_eh — I21, toolchain provisioned).

## Step 0.7 (next resume)

THIS turn = D-242 ROOT-CAUSE FOUND (DOCS-ONLY, no code): probed ALL StackOverflow raise sites → it's
`frame.pushLabel` overflowing the per-frame LABEL stack (max_label_stack=128 < validator's max_control_stack=1024,
D-241 family). PROVEN: raising max_label_stack→1024 makes go_math_big exit 0. The naive inline raise crashes a
stack-test (5MB Runtime) → fix = lazy per-frame label overflow (Active bundle). Corrected the prior 2 wrong
diagnoses + the lesson. NO code → NO ubuntu kick (prior `bca625f2` already ubuntu-OK at `95b8efe6`; Step 0.7 next
cycle = nothing to verify). Next → implement the 11.1-label-stack bundle.

**Gate hygiene**: Step-5 Mac gate = `bash scripts/mac_gate.sh`. JIT corpus: `zig build test-spec-wasm-3.0-assert`
(NO bogus `-Dno-run`); pick the exe by mtime (bare `head -1` = STALE). `ZWASM_SPEC_ENGINE=jit <exe>
test/spec/wasm-3.0-assert --fail-detail >out 2>err` (SPLIT stderr). Phase 11 adds WASI + bench gates.

## Key refs

- ROADMAP §11 (WASI 0.1 + bench + SIMD gap + GC-rooting). ADR-0128 (Phase 10); ADR-0133 (§10 re-scoped exit);
  ADR-0067 (3-host bench: Mac native + ubuntunote + windowsmini). `debug_jit_auto` skill for JIT dispatch fails.
- Lessons (this session): `2026-06-03-reprobe-blocked-by-barriers-before-scoping` (D-240 + D-210),
  `2026-06-03-jitinstance-test-compiles-for-host-arch`, `2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch`.
