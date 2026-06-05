# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase 16 (完成形) — open-ended; the loop CONTINUES, no release (ADR-0156).** The **v0.1.0-scope program is
  thoroughly complete + 3-host green** (`deb97903`): all-engine WASI (interp+JIT+AOT; D-251/D-244), realworld
  validated (D-283), full AOT-WASI syscall test matrix, accurate docs, audited scaffolding, debt clean (0 `now`),
  perf no-deficiency (D-265 closed). The 2026-06-05 bucket-3 plateau is now **superseded** by a new user-directed
  program (below).

## NEW USER-DIRECTED PROGRAM (2026-06-05) — release-readiness: benchmarks + official docs (ADR-0163)

Charter + scope + the ADR-0156 boundary (this PREPARES release artifacts; it does NOT tag/publish — release stays
user-only): **[`ADR-0163`](decisions/0163_release_readiness_bench_and_docs_program.md)**. Five workstreams; run as
ordinary Phase-16 work (survey-first; bundle multi-cycle pieces). Suggested order **B→A→C→D→E** (D/E doc-only,
can parallelise). **Start a fresh `/continue` here.**

- **A — Benchmark suite expansion (v1-level + more).** v1's `~/Documents/MyProducts/zwasm/bench/` is the breadth
  baseline (`compare_runtimes.sh`, `runtime_comparison.yaml`, `simd_comparison.yaml`, `shootout-src/`, `tinygo/`,
  `run_wasm.mjs`=Node/V8). v2 today = `bench/` (history.yaml + sightglass + per-op SIMD vs wasmtime/wazero/wasmer +
  aot_coldstart). Add: realworld WASI workloads (now JIT/AOT-runnable, NOT just interp), all-engine matrix
  (interp/JIT/AOT), startup + peak-memory. Reuse `scripts/run_bench.sh` (`--compare=all` exists). **Step 0**: diff
  v1 bench/ vs v2 bench/, list the gaps.
- **B — Multi-runtime provisioning (nix-sanctioned).** Pin wasmtime / wasmer / wazero / wasm3 (opt: wasmedge,
  Node-V8) in **`flake.nix`** as a `.#bench` dev-shell (model: the `.#gen` toolchain shell). Mirror v1's
  `compare_runtimes.sh` / `runtime_comparison.yaml` shape. **User explicitly OK'd installing into nix.**
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

`tail -3 /tmp/ubuntu.log` = `OK (HEAD=8b19faad)`; `/tmp/win.log` = `OK`. The post-bucket-3 docs commits
(`25c4146d` sockets-finding, `deb97903` bucket-3, ADR-0163 + this handover) are **docs-only — no code delta since
the 3-host-green `8b19faad`**, so no remote re-kick was needed. A fresh `/continue` resumes on the ADR-0163
program (workstream B or A), not a remote-verify.

## Deferred / open (unchanged by this program)

- **v0.2.0 / Component Model + WASI 0.2** — ROADMAP-deferred (ADR-0161 §3); needs a user scope decision (NOT this
  program). **D-281** sockets (on-demand; v1 also stubs — not a parity miss). **D-255** C-API io (ADR-0143).
  **D-211** precise GcRootMap (deferred; ADR-0148/0060). Debt ledger = 59 rows, 0 `now`.

## Key refs

- **ADR-0163** (this program). ADR-0156 (no autonomous release — the boundary). ADR-0161 (WASI program, done).
  ADR-0012 §7 / ADR-0040 (bench cadence / cold-start). ADR-0159 (CLI=run+compile). ROADMAP §12.4 (bench), §16.
- v1 bench: `~/Documents/MyProducts/zwasm/bench/`. v2: `bench/README.md`, `bench/results/*`, `scripts/run_bench.sh`,
  `.github/workflows/bench.yml`. README/docs: `README.md`, `docs/{tutorial,migration_v1_to_v2,reference/cli}.md`.
