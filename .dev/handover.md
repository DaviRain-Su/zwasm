# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase 14 (CI matrix) IN-PROGRESS — §14.0–§14.5 all `[x]`; only §14.P (close) remains.**
  **Phase 13 (C API) DONE** (ADR-0144). Phase 12 (AOT) DONE.
- **Phase-14 tasks DONE**: §14.1 `pr.yml` (3-OS test-all matrix, `2592f255`); §14.2 `bench.yml` (2-host per
  ADR-0137); §14.3 `nightly.yml` (`17e3b6f1`+`1fc63016` — fuzz campaign + proposal-watch + spec-bump);
  §14.4 `bench_baseline.yml` (`96e72c24`); §14.5 pre-push verified. All workflow_dispatch, actionlint-clean.
  Fuzz infra (D-256 resolved): parse/validate/instantiate crash-harness in test-all + the nightly campaign.
- **§14.P full-close BLOCKED on**: **D-245 win64**
  (windows CI green; remote-windows asm, §11.3/P15 home). When both land (or §14.P re-scoped) Phase 14 closes.

## Next task (autonomous)

**§14.0–§14.5 all `[x]`; only §14.P (Phase-14 close) remains.** §14.3 closed (`1fc63016` — nightly.yml 3/3:
fuzz campaign + proposal-watch + spec-bump). D-256 resolved.
**NEXT: §14.P — Phase 14 close.** §14.P (🔒 gate: NO per §14 Goal) is autonomous (not a registered hard-gate).
But its full close wants 3-host CI green, and windows is **flaky-red on D-245 win64** (host→JIT, the SAME blocker
re-scoped past at §13.P/ADR-0144). So §14.P = the §13.P pattern: **re-scope past D-245** (CI scaffolding +
fuzz infra + §14.3 done; windows-CI-green deferred to D-245's §11.3/Phase-15 home) via an ADR, run
audit_scaffolding (mandatory), windowsmini reconcile (will flaky-fail on D-245 — expected, the carry), widget
14→DONE, expand Phase 15. Then Phase 15 (perf parity + ClojureWasm). **Optional fuzzer extensions** (not §14.P
blockers): invoke-exports execution fuzzing (interp; needs export introspection); interp-vs-JIT differential
oracle (D-245-entangled). (If user redirects to D-245-win64-first, pivot.)

## Step 0.7 (next resume)

This turn: §14.3 spec-bump leg (`1fc63016`: spec_pin.yaml + check_spec_bump.sh + nightly.yml) — CI-config/docs
only, NO code change → no ubuntu kick (code HEAD `011dca7e` ubuntu-verified **OK** this resume; fuzz green on
Linux). **NOTE** (lesson `gate-tail-vs-exit-code`): benign `failed command: …--listen=-` next to a
passing Build Summary is not a failure. CI workflows: actionlint before commit.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. CI workflows: actionlint before commit. Win64
cross-compile = `zig build test -Dtarget=x86_64-windows-gnu`. windowsmini exec = `run_remote_windows.sh`.

## Deferred / open debt

- **D-245** win64 host→JIT (windows CI green) —
  §14.P blocker, §11.3/P15 home (hard remote asm). **D-249** win bench timing (ADR-0137). **D-255** C-API WASI
  io-infra (ADR-0143). **D-254** rust 3-OS (ADR-0142). **D-253** §13.2 host_info (cap). **§12.5/§11.4** GC
  stack-map → P15. **D-251** WASI in AOT. **D-246** arm64 dot/extmul → P15. **D-238** x86_64 EH thunk.
  Standing: 20 `<backfill>` markers (10 ADR + 10 lesson) → sweep before §14.P.

## Key refs

- ROADMAP §14 (table; §14.1/2/4/5 [x], §14.3 blocked, §14.P blocked). Phase Status widget (14 IN-PROGRESS).
  ADR-0144 (§13.P close, re-scope-past-D-245 pattern); ADR-0137 (2-host bench). `test/fuzz/` + `nightly.yml` (§14.3).
