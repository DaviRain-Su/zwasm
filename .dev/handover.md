# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **11 IN-PROGRESS — WASI 0.1 full + bench infra** (Phase 10 = DONE 2026-06-03, `5ab7b981`; Wasm 3.0
  complete on both backends per ADR-0133). §11 task table open (11.0✓ / 11.1 WASI / 11.2 bench / 11.3 SIMD-gap /
  11.4 GC-rooting / 11.P).
- **LAST code HEAD** (`0b4706b3`): §11.1 file-I/O bundle **cycle 1** — CLI `--dir <host>[:<guest>]` preopen wiring
  (runWasmCapturedOpts → host.addPreopen) + path_open now honors `oflags` (OFLAGS_CREAT → std.Io.Dir.createFile;
  was `_ = oflags`). Observable: `zwasm run --dir /tmp:. rust_file_io.wasm` now CREATES the file (was nothing) +
  unit test (pathOpen O_CREAT in a real tmpDir). rust_file_io still traps on the WRITE (fd_write/read to file fds
  = .notsup → bundle cycle 2). mac_gate + 2-arch xc green. Prior: fd_filestat_get/path_unlink_file (`b6224bbb`,
  preview1 16→18, facade 55 PASS), D-241 verifier-drift fix (`142f0a53`), fd_prestat/sched_yield (`237f0313`).
- **JIT corpus final** (`dbcfff1b`, ubuntu-verified `eba86890`): memory64 336/1(D-234 harness)/0, tail-call
  71/0/0, EH 34/0/0, gc 402/0/5, function-references 36/0/3, multi-memory 0/0/407(→§14). All skips = eligibility-
  gate; all 59 modrej = multi-memory. Spec corpus = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`.
- **GATE TRAP** (still live): JIT corpus exe MUST be picked by mtime (`find … -exec ls -t {} + | head -1`); bare
  `head -1` = STALE binary → masks the delta.
- **Watch**: `runner_test.zig` ~1490 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 / `validator.zig` 3204 (cap 3300, D-204) — all < hard 2000/3300.

## Active bundle

- **Bundle-ID**: 11.1-file-io (D-243)
- **Cycles-remaining**: ~1-2
- **Continuity-memo**: cycle 1 DONE (`0b4706b3`) = --dir preopen + path_open O_CREAT (file now CREATED). Cycle 2 =
  **fd_write / fd_read to FILE fds** — both currently `.notsup` (fd.zig: `.file, .dir => return .notsup`). Wire them
  via `std.Io.File{.handle=slot.host_handle}.writeAll/read` over the ciovec/iovec gather-scatter (mirror the stdio
  branch). Maybe also fd_seek for files. Then rust_file_io create+write+read+unlink works end-to-end.
- **Exit-condition**: `zwasm run --dir <tmp>:. rust_file_io.wasm` exits 0 (file written + read back + unlinked); add
  an end-to-end test (tmpDir preopen + runWasmCapturedOpts on rust_file_io → exit 0). Then the realworld runners can
  pass a temp --dir to flip rust_file_io SKIP-V2-TRAP → PASS (optional follow-up).

§10 close-hygiene RESOLVED (SHA backfill = traceability via `5ab7b981` + phase_log, no fabrication; windowsmini
DEFERRED per policy). Other §11 tracks when the file-io bundle closes: D-242 (frame stack, go_*), 11.2 bench, 11.4 GC-rooting.

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

THIS turn = §11.1 file-io bundle cycle 1 (`0b4706b3`, CODE): CLI --dir preopen + path_open O_CREAT (file now
created; unit + CLI observable). Also disproved the D-243 "facade↔CLI instantiate divergence" — it was a STALE
`zig-out/bin/zwasm` (`zig build test` doesn't rebuild the CLI binary; fresh build agrees). mac_gate (test-all+lint)
green, 2-arch xc clean. **ubuntu kick SENT** against `0b4706b3` — Step 0.7 next cycle MUST `tail -3 /tmp/ubuntu.log`;
RED → revert to `03a70d49` (last ubuntu-verified). Next → file-io bundle cycle 2 (fd_write/read to file fds).

**Gate hygiene**: Step-5 Mac gate = `bash scripts/mac_gate.sh`. JIT corpus: `zig build test-spec-wasm-3.0-assert`
(NO bogus `-Dno-run`); pick the exe by mtime (bare `head -1` = STALE). `ZWASM_SPEC_ENGINE=jit <exe>
test/spec/wasm-3.0-assert --fail-detail >out 2>err` (SPLIT stderr). Phase 11 adds WASI + bench gates.

## Key refs

- ROADMAP §11 (WASI 0.1 + bench + SIMD gap + GC-rooting). ADR-0128 (Phase 10); ADR-0133 (§10 re-scoped exit);
  ADR-0067 (3-host bench: Mac native + ubuntunote + windowsmini). `debug_jit_auto` skill for JIT dispatch fails.
- Lessons (this session): `2026-06-03-reprobe-blocked-by-barriers-before-scoping` (D-240 + D-210),
  `2026-06-03-jitinstance-test-compiles-for-host-arch`, `2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch`.
