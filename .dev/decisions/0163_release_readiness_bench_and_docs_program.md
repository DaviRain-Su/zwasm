# 0163 — Release-readiness program: comprehensive benchmarks (multi-runtime) + official OSS docs

- **Status**: Accepted (2026-06-05; user-directed program — see chat 2026-06-05).
- **Date**: 2026-06-05
- **Author**: claude (user directive, paraphrased: "zwasm v1 並みに充実したベンチを
  用意（価値があれば追加も）、他ランタイムも比較用に用意（nix に入れてよい）、その
  ドキュメントを公式に用意。リリースに向けた一般的 OSS の README 整備、ユーザーガイド
  と migration ガイドの最終 fix。今やるのでなく次のクリアセッション向けに配線する。")
- **Tags**: bench, docs, release-prep, §12.4, §16, completion-finalization,
  multi-runtime, nix, README, ADR-0156, ADR-0012, ADR-0040
- **Amends**: nothing normative — this is Phase-16 completion-finalization work
  (§16 docs + dogfooding + benchmarks). No ROADMAP §1/§2/§4/§5/§9-scope/§11/§14
  change; routine per §18.

## Context

The v0.1.0-scope program (clean / full-featured / 100% spec / lightweight-fast)
is thoroughly complete + 3-host green (all-engine WASI, D-251/D-283; see the
2026-06-05 bucket-3 handover). The user has directed a **release-readiness
program**: bring the public-facing benchmark suite + documentation up to a
publishable, "general OSS" standard before any release.

Two anchors frame the scope:

1. **v1 had a richer bench setup** — `~/Documents/MyProducts/zwasm/bench/` carries
   `compare_runtimes.sh`, `runtime_comparison.yaml`, `simd_comparison.yaml`,
   `ci_compare.sh`, `record_comparison.sh`, `shootout-src/`, `tinygo/`,
   `run_wasm.mjs` (Node/V8 comparison), etc. v2's `bench/` (history.yaml +
   sightglass + per-op SIMD profile vs wasmtime/wazero/wasmer) is a subset. The
   user wants **v1-level breadth, plus more where valuable**.
2. **One stale bench note** — `bench/results/s15p_parity_vs_v1.md` says
   "v2 `--engine=jit` is compute-only (no WASI)", which D-244 made FALSE. The
   re-profile should drop that constraint (JIT + AOT now do full WASI → realworld
   WASI workloads are JIT/AOT-benchable).

## Decision

Open a user-directed **release-readiness program** with five workstreams (A–E).
Run it as ordinary Phase-16 completion work (bundle multi-cycle pieces per
ADR-0118 D6; survey-first per the loop).

- **A. Benchmark suite expansion** — reach v1-level breadth + add value:
  compute (SIMD per-op, scalar, sightglass shootout: bz2/quicksort/etc.),
  realworld WASI workloads (now JIT/AOT-runnable, not just interp), all-engine
  matrix (interp vs JIT vs AOT), AOT cold-start (§12.4), startup + peak-memory.
  Reuse/upgrade `scripts/run_bench.sh` (`--compare=all` exists) + `bench/`.
- **B. Multi-runtime comparison provisioning** — wasmtime, wasmer, wazero,
  wasm3, (optionally wasmedge / Node-V8). **Pin them in `flake.nix`** (a new
  dev-shell input, e.g. `.#bench`) so comparisons are reproducible + hermetic;
  installing into nix is explicitly sanctioned by the user. Mirror v1's
  `compare_runtimes.sh` / `runtime_comparison.yaml` shape.
- **C. Official benchmark documentation** — a polished, public-repo-quality page
  (`docs/benchmarks.md` or `docs/reference/benchmarks.md`): methodology, host
  matrix, results vs other runtimes + vs v1, reproduction commands, caveats
  (startup-confound, `--quick` vs steady-state). Linked from README.
- **D. OSS README.md** — general open-source README: one-line pitch, badges
  (build/license), feature highlights, install, quickstart (`run`/`compile`),
  engine table, WASI/proposal support matrix, benchmark link, embedding (Zig/C
  API), contributing, license. Keep the accurate "all-engine WASI; jit adds
  SIMD" framing (per the 2026-06-05 doc-accuracy fix).
- **E. User guide + migration guide final fix** — bring `docs/tutorial.md`
  (user guide) and `docs/migration_v1_to_v2.md` to release quality (complete,
  accurate, example-verified). The migration guide already had its
  compute-only/WASI claims corrected (`046c6b9e`); the final pass verifies
  examples run and the surface description matches the settled CLI/API.

### Boundary — ADR-0156 still holds (no autonomous release)

This program **prepares** release artifacts (benchmarks + docs). It does NOT
tag, publish, cut over to `main`, or bump a version — those remain **manual,
user-only** acts (ADR-0156). The loop produces a publishable README / bench
page / guides; the user performs the actual release. "Release-readiness" =
the docs/benchmarks are ready, NOT that a release is cut.

## Consequences

- The bucket-3 plateau (2026-06-05) is superseded by this active program; the
  next `/continue` resumes on workstream A or B (survey-first).
- `flake.nix` gains a bench dev-shell with pinned comparator runtimes (B); the
  `nix develop .#gen` toolchain shell is the model.
- New committed docs: `docs/benchmarks.md`, an upgraded `README.md`, finalized
  `docs/tutorial.md` + `docs/migration_v1_to_v2.md`. `bench/` gains the
  multi-runtime comparison harness + a refreshed (WASI-inclusive) parity result.
- Sequencing is the loop's judgment; a reasonable order is **B (provision
  comparators) → A (expand + run benches) → C (bench docs) → D (README) →
  E (guides)**, but D/E can proceed in parallel (doc-only, no comparator dep).

## References

- v1 bench: `~/Documents/MyProducts/zwasm/bench/` (compare_runtimes.sh,
  runtime_comparison.yaml, simd_comparison.yaml, shootout-src/, tinygo/,
  run_wasm.mjs).
- v2 current: `bench/README.md`, `bench/results/{history.yaml,
  simd_gap_profile_p11_3.md, s15p_parity_vs_v1.md, aot_coldstart.md}`,
  `scripts/run_bench.sh`, `.github/workflows/bench.yml`.
- ADR-0156 (no autonomous release — the boundary). ADR-0012 §7 + ADR-0040
  (bench cadence / cold-start). ADR-0159 (CLI = run+compile). ROADMAP §12.4
  (bench cadence), §16 (completion-finalization).
