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

Fuzz infra: parse+validate+instantiate crash-fuzz (`6c80c229`+`16584c1c`); `nightly.yml` `17e3b6f1` = fuzz
campaign + proposal-watch (2/3 of §14.3). **§14.3 last leg = spec-bump** but it needs a **Wasm-3.0 pin-target
decision first** (recorded pin is Phase-9 `wg-2.0`, no enforced SHA; overlaps proposal-watch) — a design chunk,
likely an ADR. **Options (pick):** (a) **make the spec-bump pin-target decision** (ADR: pin to Wasm-3.0 W3C-Rec
spec/testsuite SHA) + build `check_spec_bump.sh` (git ls-remote upstream vs pin) → **closes §14.3**; (b) re-scope
§14.P to close Phase 14 (CI scaffolding + fuzz infra done; spec-bump + D-245 → homes), advance to Phase 15;
(c) **fuzz invoke-exports** extension (execution fuzzing; needs export introspection — src/ helper or §13.2 C-API);
(d) **D-245 win64** (the real §14.P/Phase-15 blocker; hard remote asm). **Lean (a) or (b)** to converge Phase 14.

## Step 0.7 (next resume)

This turn: §14.3 `nightly.yml` (`17e3b6f1`) + `fuzz-campaign` build step + `check_proposal_watch.sh`. Prior
`f26fe7b0` (instantiate) ubuntu test-all **OK** (fuzz green on Linux). An ubuntu test-all kicked for the
build.zig change → next resume `tail /tmp/ubuntu.log` for `OK` (fuzz-campaign step is NOT in test-all; test-fuzz
seed unaffected). **NOTE** (lesson `gate-tail-vs-exit-code`): benign `failed command: …--listen=-` next to a
passing Build Summary is not a failure. CI workflows: actionlint before commit.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. CI workflows: actionlint before commit. Win64
cross-compile = `zig build test -Dtarget=x86_64-windows-gnu`. windowsmini exec = `run_remote_windows.sh`.

## Deferred / open debt

- **D-256** fuzz infra — **partial** (crash-harness + instantiate done; spec-bump + nightly wiring remain).
  **D-245** win64 host→JIT (windows CI green) —
  §14.P blocker, §11.3/P15 home (hard remote asm). **D-249** win bench timing (ADR-0137). **D-255** C-API WASI
  io-infra (ADR-0143). **D-254** rust 3-OS (ADR-0142). **D-253** §13.2 host_info (cap). **§12.5/§11.4** GC
  stack-map → P15. **D-251** WASI in AOT. **D-246** arm64 dot/extmul → P15. **D-238** x86_64 EH thunk.
  Standing: 20 `<backfill>` markers (10 ADR + 10 lesson) → sweep before §14.P.

## Key refs

- ROADMAP §14 (table; §14.1/2/4/5 [x], §14.3 blocked, §14.P blocked). Phase Status widget (14 IN-PROGRESS).
  ADR-0144 (§13.P close); ADR-0137 (2-host bench). D-256 (fuzz, the bundle). `build.zig` test-all wiring.
