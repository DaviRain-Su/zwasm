# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase 14 (CI matrix) IN-PROGRESS** — CI-scaffolding tasks DONE; §14.P blocked on 2 substantial items.
  **Phase 13 (C API) DONE** (ADR-0144). Phase 12 (AOT) DONE.
- **Phase-14 thin CI DONE**: §14.1 `pr.yml` (3-OS test-all matrix, `2592f255`); §14.2 `bench.yml` (2-host
  per ADR-0137); §14.4 `bench_baseline.yml` (`96e72c24`); §14.5 pre-push verified. All workflow_dispatch
  (manual; §14.5 CI-second-line), actionlint-clean.
- **§14.3 PARTIAL (D-256)** — **fuzz crash-harness BUILT** `6c80c229`: `test/fuzz/fuzz_loader.zig` (parse +
  Engine.compile each input; crash=finding) + `gen_fuzz_corpus.sh` (smith + malformed) + `test-fuzz` in
  test-all (29-file seed corpus, 0 crashes). REMAINING for §14.3: spec-bump checker (still absent) + nightly.yml
  campaign wiring; differential oracle = extension. D-256 now `partial`.
- **§14.P full-close BLOCKED on**: D-256-remaining (spec-bump + nightly wiring, §14.3) **+ D-245 win64**
  (windows CI green; remote-windows asm, §11.3/P15 home). When both land (or §14.P re-scoped) Phase 14 closes.

## Next task (autonomous)

**Options (pick highest-value):** (a) **differential oracle** for the fuzzer — run each corpus module through
interp AND JIT, compare results/traps (catches miscompiles, the bug-class fuzzing is best at; Mac-local,
high-value extension of `6c80c229`); (b) **spec-bump checker** + wire §14.3 `nightly.yml` (fuzz campaign), then
§14.3 closes; (c) re-scope §14.P to close Phase 14 (CI scaffolding done) deferring spec-bump + D-245. Lean (a)
or (b) — real feature work over re-scoping. (If user redirects to D-245-win64-first or Phase-15, pivot.)
or Phase-15, pivot.)

## Step 0.7 (next resume)

This turn: §14.4 (`bench_baseline.yml`, `96e72c24`) + §14.5 [x]. CI-config + docs only → no ubuntu kick
(code HEAD `528d2af3` ubuntu-verified OK). **NOTE** (lesson `gate-tail-vs-exit-code`): benign `failed
command: …--listen=-` noise next to a passing Build Summary is not a failure. Mac gate clean at `528d2af3`.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. CI workflows: actionlint before commit. Win64
cross-compile = `zig build test -Dtarget=x86_64-windows-gnu`. windowsmini exec = `run_remote_windows.sh`.

## Deferred / open debt

- **D-256** fuzz+spec-bump infra absent — **ACTIVE BUNDLE**. **D-245** win64 host→JIT (windows CI green) —
  §14.P blocker, §11.3/P15 home (hard remote asm). **D-249** win bench timing (ADR-0137). **D-255** C-API WASI
  io-infra (ADR-0143). **D-254** rust 3-OS (ADR-0142). **D-253** §13.2 host_info (cap). **§12.5/§11.4** GC
  stack-map → P15. **D-251** WASI in AOT. **D-246** arm64 dot/extmul → P15. **D-238** x86_64 EH thunk.
  Standing: 20 `<backfill>` markers (10 ADR + 10 lesson) → sweep before §14.P.

## Key refs

- ROADMAP §14 (table; §14.1/2/4/5 [x], §14.3 blocked, §14.P blocked). Phase Status widget (14 IN-PROGRESS).
  ADR-0144 (§13.P close); ADR-0137 (2-host bench). D-256 (fuzz, the bundle). `build.zig` test-all wiring.
