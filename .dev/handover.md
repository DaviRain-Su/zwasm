# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase 16 (完成形) — open-ended; the loop CONTINUES, no release (ADR-0156).** The **v0.1.0-scope program is
  thoroughly complete + 3-host green** (`deb97903`): all-engine WASI (interp+JIT+AOT; D-251/D-244), realworld
  validated (D-283), full AOT-WASI syscall test matrix, accurate docs, audited scaffolding, debt clean (0 `now`),
  perf no-deficiency (D-265 closed). The 2026-06-05 bucket-3 plateau is now **superseded** by a new user-directed
  program (below).

## USER-DIRECTED PROGRAM (2026-06-05) — release-readiness: benchmarks + official docs (ADR-0163)

Charter + scope + the ADR-0156 boundary (this PREPARES release artifacts; it does NOT tag/publish — release stays
user-only): **[`ADR-0163`](decisions/0163_release_readiness_bench_and_docs_program.md)**. Five workstreams; run as
ordinary Phase-16 work (survey-first; bundle multi-cycle pieces). Order **B→A→C→D→E** (D/E doc-only, parallel-OK).

- **B — Multi-runtime provisioning. ✅ DONE (`310314bb`).** `flake.nix` gained `devShells.bench` pinning
  wasmtime/wazero/wasmer/wasmedge (Mac-host-only; test hosts never build it). `run_bench.sh --compare` learned
  `wasmedge` (`wasmedge WASM`, WASI _start; interpreter by default). **wasm3 deliberately excluded** (nixpkgs marks
  0.5.0 insecure — 8 CVEs, unmaintained; not in v1's set → no parity lost). End-to-end verified: `--bench=tinygo/fib
  --compare=all --quick` → all 5 runtimes (zwasm 5.31 / wasmtime 6.87 / wazero 5.92 / wasmer 11.48 / wasmedge 13.47
  ms — startup-dominated tiny workload). node/bun still deferred (need JS WASI wrapper → A).
- **A — Benchmark suite expansion (v1-level + more). ← IN PROGRESS.** Done so far: **all-engine matrix**
  (`3195fda3`) — `run_bench.sh --engines=interp,jit,aot` benches zwasm across its 3 engines (one runtime row each;
  aot precompiles a temp .cwasm, net-zero cleanup; combinable with `--compare=all`). Verified on tinygo/fib
  (interp 2.11 / jit 2.44 / aot 2.00 ms). **NEXT A chunks**: (1) **full-inventory re-profile** — run the engine
  matrix × `--compare=all` over the whole `BENCHES` inventory + capture RSS, record a fresh result; this is a heavy
  multi-min run (do foreground or timeout-bounded bg). (2) **Refresh the stale `bench/results/s15p_parity_vs_v1.md`**
  from that data (it falsely says "jit compute-only/no WASI" — D-244 fixed it; JIT+AOT run the tinygo/cljw WASI
  fixtures). (3) optional node/bun V8 comparator (build a JS WASI wrapper, v1's `run_wasm.mjs`). v1 breadth
  baseline: `~/Documents/MyProducts/zwasm/bench/`.
- **C — Official benchmark docs.** Public-quality `docs/benchmarks.md` (or `docs/reference/benchmarks.md`):
  methodology, host matrix, results vs other runtimes + vs v1, reproduction, caveats (startup-confound). Link from
  README.
- **D — OSS README.md.** General open-source README: pitch, badges, features, install, quickstart, engine table,
  WASI/proposal matrix, bench link, embedding (Zig/C API), contributing, license. Keep the accurate "all-engine
  WASI; jit adds SIMD" framing (`046c6b9e`).
- **E — User + migration guide final fix.** `docs/tutorial.md` + `docs/migration_v1_to_v2.md` to release quality
  (complete, accurate, examples verified-to-run). Migration compute-only claims already corrected (`046c6b9e`).

**Known stale to fix during A**: `bench/results/s15p_parity_vs_v1.md` says "v2 jit is compute-only (no WASI)" —
FALSE since D-244; re-profile WITH realworld WASI workloads (JIT+AOT now run them).

## Step 0.7 (next resume) — verify remote logs

Last 3-host green = `8b19faad`. All B + A commits so far (`20de319d`, `310314bb`, `3195fda3`) touch only
`flake.nix` (NEW `devShells.bench` — `default` untouched) + `scripts/run_bench.sh` (a Mac-host bench script, not
run by `test-all`) → **no `src/` delta since `8b19faad`**, so no remote re-kick. A fresh `/continue` resumes on
**workstream A chunk (1)**: the full-inventory engine-matrix re-profile, not a remote-verify.

## Deferred / open (unchanged by this program)

- **v0.2.0 / Component Model + WASI 0.2** — ROADMAP-deferred (ADR-0161 §3); needs a user scope decision (NOT this
  program). **D-281** sockets (on-demand; v1 also stubs — not a parity miss). **D-255** C-API io (ADR-0143).
  **D-211** precise GcRootMap (deferred; ADR-0148/0060). Debt ledger = 59 rows, 0 `now`.

## Key refs

- **ADR-0163** (this program). ADR-0156 (no autonomous release — the boundary). ADR-0161 (WASI program, done).
  ADR-0012 §7 / ADR-0040 (bench cadence / cold-start). ADR-0159 (CLI=run+compile). ROADMAP §12.4 (bench), §16.
- v1 bench: `~/Documents/MyProducts/zwasm/bench/`. v2: `bench/README.md`, `bench/results/*`, `scripts/run_bench.sh`,
  `.github/workflows/bench.yml`. README/docs: `README.md`, `docs/{tutorial,migration_v1_to_v2,reference/cli}.md`.
