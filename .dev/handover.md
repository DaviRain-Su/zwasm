# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)
- **Meta-pivot bundle SHIPPED 2026-05-26** (ADR-0118): rule
  consolidation, skill split, CLAUDE.md slim, hook overhead reduction,
  bundle-mode state machine. Commits `0b0a514d..2ce59032`.
- **10.D = CLOSED 2026-05-25**: 全 7 ADR (0111-0117) Accepted.
- **10.M sub-chunks 1..fixture-2 = SHIPPED**: memory64 impl complete.
- **10.R sub-chunks 1..5 = SHIPPED**: parent gated on 10.G.
- **10.TC-1 = SHIPPED** (`a83e095f`): return_call interp side.
- **10.G-i31-ops / 10.G-2 / 10.G-3 = SHIPPED**.
- **10.E interp side = COMPLETE 2026-05-26**: tag-section + throw +
  try_table + catch family + cross-frame unwind + exnref.
- **10.E codegen IT-1 = SHIPPED**: try_table dispatched via
  per-op file; `EmitCtx.exception_table_builder` populated when
  `func.instrs` contains `.try_table`; per-op `std.debug.assert`
  enforces the invariant for IT-2+.

## ROADMAP §10 progress

- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS (4): 10.M (7/8) / 10.R (5/5; gated on 10.G) /
  10.TC (codegen + cross-module + spec corpus 残) /
  10.E (codegen integration IT-2..IT-6 残)
- Pending (3): 10.G / 10.P (close gate)

## Active bundle

- **Bundle-ID**: `10.E-codegen-IT-1..IT-3`
- **Cycles-remaining**: `~2` (IT-1 shipped; IT-2 + IT-3 remain)
- **Continuity-memo**: try_table emit body (Builder.add per catch)
  → throw/throw_ref CALL dispatchThrow + payload marshalling
- **Exit-condition**: end-to-end `throw 0 / catch_all` fixture
  reaches the dispatcher; `Builder.entries.len > 0` after compile
  of a try_table function

Step 1b of resume routes to bundle-next-step (IT-2: try_table emit
body in `src/engine/codegen/{arm64,x86_64}/ops/wasm_3_0/try_table.zig`,
per `.dev/phase10_eh_integration_plan.md` §IT-2).

## Open questions / blockers

- 10.G-4 (struct ops) — blocked-by GC heap impl
- 10.M-realworld — toolchain-blocked (clang_wasm64 fixture)
- 10.P close gate — user touchpoint by construction

## Key refs

- **ADR-0118** (`.dev/decisions/0118_meta_loop_consolidation.md`)
- **Integration plan** (`.dev/phase10_eh_integration_plan.md`) —
  IT-1..IT-6
- **ROADMAP §10**
- **Phase 10 design plan** (`.dev/phase10_design_plan_ja.md`)
- **Phase log** (`.dev/phase_log/phase10.md`)
- **Lesson** `2026-05-26-eh-codegen-foundation-atom-rhythm.md`
  (`e62db476`)
