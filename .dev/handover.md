# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **ROADMAP widget: Phase 17 = IN-PROGRESS (feature line)** — the
  **CM + WASI-P2 wasmtime-equivalent campaign CLOSED 2026-06-13**
  (component_model_plan.md ARCHIVED-IN-PLACE; Retrospective filled:
  Tier 2 EXCEEDED — typed embedder API ADR-0183, sockets incl. windows
  AFD readiness with D-319 discharged, guest-defined resources D-322,
  component default-ON ADR-0182, validator rules 1–12, corpus
  **158/0/0**, rust+tinygo proofs 3-host green).
- **Campaign-close audit DONE** (private/audit-2026-06-13.md): 0 block;
  3 soon ALL FIXED inline (validate.zig/types.zig stale headers; 14
  blocked-by rows re-walked + dates refreshed). Health good.
- **Docs sweep DONE**: README CM row reality-synced (was: "opt-in,
  default false, rules 1-4, parked" — now default-ON / campaign complete
  / 158/0/0) + zig_api_design §3.9 extended with resources/handles +
  instance-path addressing.
- **Simplify sweep COMPLETE (3/3)**: component_wasi_p2 -31 LOC
  (err-result helpers) · canon.zig stale B-chunk prose cleared
  (comment-only) · validate.zig NULL (audited healthy — candidate folds
  all fail the churn bar). Campaign-grown surfaces are clean.
- **NOW-pointer: completion-refinement continues** — NEXT: debt
  long-tail walk (Step 0.5 picks from the 58-entry ledger; zero `now`
  rows — the long-tail is blocked-by/note re-evaluation + any
  dischargeable `partial` rows) · D-323 stays blocked-by (stdlib).
  Open user item: ADR-0184 (Proposed) awaits review.
- **Open user-decision item**: ADR-0184 Proposed (C-API engine-owned io
  — ADR-0143 surface reversal; loop does NOT implement until reviewed).
- **Other open**: D-323 (stdlib NTSTATUS, blocked-by) · D-318 (note,
  non-gating Rosetta limitation) · §1.3 backlog demand-driven.

## Closed-work pointers (detail in git log / ADRs)

- **d314-jit-sandbox CLOSED 2026-06-12** (interrupt/fuel/mem-cap triad on
  both engines + CLI + C-API; ADR-0179). **GATE NOTE (D-311 residual)**:
  raw-entry-call tests crash seed-flakily in `zig build test` (at-exit IPC
  variant prints `failed command:` but exits 0); 3-host test-all is the
  authority (`releasesafe_jit_failures.md`).
- **JIT-correctness pass 2026-06-12**: wasm-3.0 JIT assert_return 880/0 on
  BOTH arches (`e758412a..9a9b46de`). D-318 (note): Rosetta x86_64-macos
  corpus-JIT SEGVs, local-diagnostic only.
- Earlier: embedder-hardening · Tier-1 static-lib · interp sandboxing ·
  musl (ADR-0178) · host-infra hardening (`3e501d9c`).
- **Open user-decision follow-ons**: D-251 (C-API WASI preopen io ADR);
  Tier-2 #5 ILP32/watchOS.

## State at pause (stable baseline)

- **Core Wasm 1.0/2.0/3.0**: 100% spec, 0 skip, 3-host green. v0.2 features +
  official corpora complete. WASI 0.1 complete. Sandboxing triad everywhere.
- **CM + WASI-P2**: default-ON (ADR-0182); real Rust/Go wasip2 components run
  e2e; typed API (ADR-0183); validator rules 1–9; corpus 139/0/19.
- **Surfaces**: C-API 293/293 · Zig-API complete (docs §3.9) · lean CLI ·
  memory-safety sound · dogfooded into cw v1. Runners ReleaseSafe (ADR-0177).
- Debt ledger: zero `now` rows; rest `blocked-by`/`note` long-tail (32
  blocked-by = call_ref / future proposals).

## Key refs

- [`docs/handoff_cw_v1.md`](../docs/handoff_cw_v1.md) — consumer-side handoff.
- **ADR-0179** (sandboxing, Revisions 2026-06-12) · **ADR-0156** (no release) ·
  **ADR-0153** (rework posture) · **ADR-0174** (windows gate) ·
  **ADR-0170/0176/0177** (CM / validation / runners).
- [`component_model_plan.md`](component_model_plan.md) ·
  [`releasesafe_jit_failures.md`](releasesafe_jit_failures.md) (D-311 residual).
