# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `228d2d79` — D-181 CLOSED. memory64 i64-idx runner test
  now exercises Mac aarch64 + Linux x86_64 SysV; ubuntu run @
  `228d2d79` exit 0. Discharged row moved to debt §Discharged.
- **10.D = CLOSED 2026-05-25**, **10.M sub-chunks 1..fixture-2,
  10.R 1..5, 10.TC-1, 10.G-i31-ops/2/3, 10.E (codegen + interp +
  IT-6 bundle full)**: all SHIPPED.
- **10.E IT-6 BUNDLE CLOSED** (`c9b9d16c` → corrected at `a98c7b1f`):
  end-to-end `throw + catch_all` returns 42 + tagged `catch $e1`
  returns 77 + uncaught variant traps. Both arches actually wired
  (was previously Mac-only-hidden by gate; D-180 caught this).
- **Win64 trampoline body SHIPPED** (`ce169224`): cross-compile
  green; runtime gate stays at phase boundary.
- **D-180 structural defenses SHIPPED** (`2808bc81` + `a98c7b1f`):
  x86_64 `usesRuntimePtr` whitelist drift detector +
  `test_discipline.md` §4 (host-only test gates must pair with
  debt-row OR spec-pinned rationale) + lesson
  `2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md`.

## ROADMAP §10 progress

- DONE (8/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D /
  10.E.
- IN-PROGRESS (3): 10.M (7/8) / 10.R (5/5; gated on 10.G) / 10.TC.
- Pending (2): 10.G / 10.P (close gate).

## Active task — throw_ref op emit body (IT-6 follow-on)

Next chunk = **throw_ref op + 10.E-N tag-equality dispatch**
per `.dev/phase10_eh_integration_plan.md` §IT-6 follow-on +
phase log §10.E-N entries:
- 10.E-N-1: `Module.tags` wiring through validator
- 10.E-N-2: interp-side production tag_param_counts wiring
- 10.E-N-3: codegen-side tag-equality + payload push at
  catch_/catch_ref dispatch (cycle 3c-iv scope; throw_ref pops
  exnref + dereferences)

Existing IT-6 catch_all + throw frame already wired both arches
(D-180 close confirmed). exnref dispatch is the open follow-on
that converts "throw_ref pops any exnref + uncaught" path into
"throw_ref + catch_ref payload push".

## Next candidates (names + Refs; no predictions)

- **10.E-N-1 / N-2 / N-3** — exnref dereferencing + Module.tags.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).
- **10.TC** — Wasm 3.0 spec corpus extension wiring into the
  spec runner.

## Open questions / blockers

- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0017 (pinned rt regs X19/R15); ADR-0026 (Cc-pivot).
- ADR-0111 (memory64; D4 emit shape underwrites D-181).
- ADR-0114 (EH design), ADR-0119 (naked-Zig trampoline).
- Integration plan `.dev/phase10_eh_integration_plan.md`.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md`.
- Lessons (Phase 10 EH cycle):
  - `2026-05-26-eh-codegen-foundation-atom-rhythm.md` (`e62db476`)
  - `2026-05-28-eh-test-wrapper-host-fp-walk-segv.md`
  - `2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md`
