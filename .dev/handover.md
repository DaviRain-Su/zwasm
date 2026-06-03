# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Active bundle

- **Bundle-ID**: D-256-fuzz-infra (build the §3-scope fuzz infrastructure; unblocks §14.3)
- **Cycles-remaining**: ~4–6 (corpus gen → loader → test-fuzz step → differential oracle)
- **Continuity-memo**: fuzz infra is ABSENT (no `test/fuzz/`, no `test-fuzz` step). MVP build order:
  (1) `test/fuzz/fuzz_loader.zig` — take a `[]u8` blob → run through `parse` → `validate` (+ optionally
  interp a `_start`/exported func), catching panics/crashes, no false-positive on legitimate parse/validate
  rejects (those return errors, not crashes); (2) `zig build test-fuzz` step running the loader over a small
  committed seed corpus + a `wasm-tools smith`-generated batch (smith is in flake.nix; gen Mac-only like the
  realworld fixtures); (3) wire `test-fuzz` into test-all (smoke) — full campaigns are the nightly (§14.3);
  (4) differential oracle (interp vs JIT, or vs wasmtime) as a later cycle. Survey v1's fuzz approach +
  `std.testing.fuzz` (Zig 0.16) + the parse/validate entry signatures first.
- **Exit-condition**: `zig build test-fuzz` exists + green on Mac (runs N≥5 smith/seed modules through
  parse+validate without false-crash); then §14.3 `nightly.yml` can wire the campaign.

## Current state

- **Phase 14 (CI matrix) IN-PROGRESS** — CI-scaffolding tasks DONE; §14.P blocked on 2 substantial items.
  **Phase 13 (C API) DONE** (ADR-0144). Phase 12 (AOT) DONE.
- **Phase-14 thin CI DONE**: §14.1 `pr.yml` (3-OS test-all matrix, `2592f255`); §14.2 `bench.yml` (2-host
  per ADR-0137); §14.4 `bench_baseline.yml` (`96e72c24`); §14.5 pre-push verified. All workflow_dispatch
  (manual; §14.5 CI-second-line), actionlint-clean.
- **§14.3 BLOCKED-BY D-256** (nightly-fuzz; fuzz+spec-bump infra absent — the ACTIVE BUNDLE builds it).
- **§14.P full-close BLOCKED on**: D-256 (fuzz, §14.3) **+ D-245 win64** (windows CI green). When both land
  (or §14.P is re-scoped) Phase 14 closes. D-245 win64 = remote-windows asm (hard); deferred to §11.3/P15.

## Next task (autonomous — bundle)

**Work the D-256-fuzz-infra bundle** (above). Step 0: dispatch an Explore subagent — v1 fuzz harness design
(`~/Documents/MyProducts/zwasm/` reference) + `wasm-tools smith` corpus recipe + the `parse`/`validate` entry
signatures + Zig-0.16 `std.testing.fuzz`. Then build MVP chunk (1)+(2)+(3). Mac-local-verifiable (no remote).
**NOTE**: stop re-scoping-to-close — this is real feature work. (If the user redirects to D-245-win64-first
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
