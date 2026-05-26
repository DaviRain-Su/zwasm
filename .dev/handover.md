# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `a98c7b1f` — D-180 closed (root-caused), structural
  defenses landed. Mac aarch64 + Linux x86_64 SysV BOTH green
  (2003/2017 pass on Mac, ubuntu OK at HEAD). Windowsmini =
  phase-boundary per ADR-0067.
- **10.D = CLOSED 2026-05-25**, **10.M sub-chunks 1..fixture-2,
  10.R 1..5, 10.TC-1, 10.G-i31-ops/2/3, 10.E (codegen + interp +
  IT-6 bundle full)**: all SHIPPED.
- **10.E IT-6 BUNDLE CLOSED** (`c9b9d16c` → corrected at `a98c7b1f`):
  end-to-end `throw + catch_all` returns 42 + tagged `catch $e1`
  returns 77 + uncaught variant traps. Both arches actually wired
  (was previously Mac-only-hidden by gate; D-180 caught this).
- **Win64 trampoline body SHIPPED** (`ce169224`): cross-compile
  green; runtime gate stays at phase boundary.
- **op_throw tag_idx marshal SHIPPED** (`81e1bd9a`).
- **D-180 root cause + structural defenses SHIPPED** (`2808bc81` +
  `a98c7b1f`): x86_64 `usesRuntimePtr` whitelist drift detector +
  `test_discipline.md` §4 (host-only test gates must pair with
  debt-row OR spec-pinned rationale) + lesson
  `2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md`.

## ROADMAP §10 progress

- DONE (8/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D /
  10.E.
- IN-PROGRESS (3): 10.M (7/8) / 10.R (5/5; gated on 10.G) / 10.TC.
- Pending (2): 10.G / 10.P (close gate).

## Next candidates (names + Refs)

- **D-181** — x86_64 SysV i64-indexed memory ops (`emitMemOpI64`
  X-form + wrap-check per ADR-0111 D4). Ungates the memory64
  runner test from Mac-only.
- **throw_ref op** — exnref dereferencing (cycle 3c-iv scope per
  the EH integration plan §IT-6 follow-on).
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).
- **10.TC** — Wasm 3.0 spec corpus extension wiring into the
  spec runner.

## Open questions / blockers

- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0017 (pinned rt regs X19/R15); ADR-0026 (Cc-pivot).
- ADR-0114 (EH design), ADR-0119 (naked-Zig trampoline).
- Integration plan `.dev/phase10_eh_integration_plan.md`.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md`.
- Lessons (Phase 10 EH cycle):
  - `2026-05-26-eh-codegen-foundation-atom-rhythm.md` (`e62db476`)
  - `2026-05-28-eh-test-wrapper-host-fp-walk-segv.md`
  - `2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md`
