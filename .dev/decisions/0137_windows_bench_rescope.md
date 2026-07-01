# 0137 — §11.2 / §11.P bench criterion re-scoped to 2-host (Mac + Linux); Windows bench deferred (hyperfine absent on windowsmini)

- **Status**: Accepted (2026-06-03; autonomous per ADR-0132)
- **Date**: 2026-06-03
- **Author**: claude (autonomous roadmap re-scoping per ADR-0132)
- **Tags**: Phase 11, §11.2, §11.P, bench, hyperfine, windowsmini, 3-host, 2-host, deferred, ROADMAP §18
- **Amends**: ROADMAP §11 task table (rows 11.2, 11.P bench criterion); `.dev/debt.yaml` (new deferred-infra row)
- **Authorised-by**: ADR-0132 (autonomous cross-phase re-scope for a phase criterion that references
  genuinely-absent, not-autonomously-provisionable infra)

## Context

§11.2 ("Bench infra — per-merge auto-recording Mac native + ubuntunote + **windowsmini SSH** into
`bench/history.yaml`") and §11.P's exit criterion ("bench auto-record **3-host**") both require bench
auto-recording on windowsmini. Confirmed absence (extended_challenge Step 1, 2026-06-03):

1. `ssh windowsmini "where hyperfine"` → `NO_HYPERFINE`. `run_bench.sh` drives `hyperfine` (pinned in
   the nix dev shell); windowsmini runs native `zig.exe` with **no nix shell**, so it has no hyperfine.
2. `scripts/run_remote_windows.sh` has **no bench step** (test-all only).

Self-provision (extended_challenge Step 2) is out of autonomous scope: installing hyperfine on
windowsmini is a **global Windows install** (scoop/winget/cargo), not a project-managed nix-shell tool —
per the rule's "out of scope: global system config / non-project-managed installs (ask user)".

The **primary** Phase-11 criteria are all met and 3-host-verified: 50 realworld Mac+Linux + Windows
realworld subset (windowsmini run-2 `bbc4900b` GREEN: realworld_runner 55/55, zig_facade 55 PASS) +
SIMD gap profile (`simd_gap_profile_p11_3.md`) + bench auto-record on **Mac + Linux** (committed
`history.yaml` rows). Only the Windows *bench-timing* 3rd host is blocked — a perf-recording
nice-to-have, not a correctness gate.

## Decision

Re-scope §11.2 + §11.P's bench criterion from **3-host** to **2-host (Mac + Linux)** bench
auto-recording. The windowsmini bench-recording is **deferred** to a future infra task (provision
hyperfine on windowsmini OR add a non-hyperfine native-timing path to `run_remote_windows.sh`),
tracked as a debt row. Windows remains a full **correctness** gate (test-all reconcile, the actual
3-host invariant per ADR-0067) — only its *bench timing* is deferred.

## Consequences

- §11.2 + §11.P bench criterion text updated to "Mac + Linux (windowsmini bench deferred — D-NNN)".
- New debt row: provision Windows bench timing (hyperfine-on-windowsmini or native path) — discharge
  when windowsmini can append a `history.yaml` row.
- The 3-host **correctness** invariant (ADR-0067) is untouched: windowsmini still runs the full
  phase-boundary `test-all` reconcile (just landed GREEN, restoring it post-Phase-10-EH/GC-on-JIT).
- No code change; ROADMAP + debt only.

> **Doc-state**: ACTIVE
