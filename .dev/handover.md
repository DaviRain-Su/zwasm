# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)
- **Meta-pivot bundle SHIPPED 2026-05-26** (ADR-0118): rule
  consolidation 29 → 19; skill split (`continue/SKILL.md` 1036 → 293
  LOC); CLAUDE.md slim + frozen-content extraction; hook overhead
  reduction; bundle-mode state machine. See ADR-0118 + commits
  `0b0a514d..2ce59032` (+ verification commit).
- **10.D = CLOSED 2026-05-25**: 全 7 ADR (0111-0117) Accepted; impl
  rows unlocked.
- **10.M sub-chunks 1..fixture-2 = SHIPPED**: memory64 impl complete.
- **10.R sub-chunks 1..5 = SHIPPED**: 5 ref-null/call_ref ops shipped;
  parent row `[ ]` (typed reftype precision blocked-by 10.G).
- **10.TC-1 = SHIPPED** (`a83e095f`): return_call + return_call_indirect
  interp.
- **10.G-i31-ops / 10.G-2 / 10.G-3 = SHIPPED**: i31 ops + needs_gc_heap
  predicate + heap-top reftype scanner.
- **10.E interp side = COMPLETE 2026-05-26**: tag-section parser +
  throw/throw_ref + try_table + 4 catch flavors + cross-frame unwind +
  exnref + production tag_param_counts.
- **10.E codegen foundation = 13-atom chain shipped** (lesson
  `e62db476` — bundling pivot needed for integration).

## ROADMAP §10 progress

13-row task table:
- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS (4): 10.M (7/8) / 10.R (5/5; parent gated on 10.G) /
  10.TC (codegen + cross-module + spec corpus 残) / 10.E (codegen
  integration IT-1..IT-6 残)
- Pending (3): 10.G / 10.P (close gate; user touchpoint by construction)

## Active chunk — Phase 10 EH-on-JIT integration

Next continuous session picks up the **IT-1+IT-2 bundle** per
`.dev/phase10_eh_integration_plan.md` (ACTIVE). The integration plan
consolidates the 13-cycle foundation chain into 6 tasks (IT-1..IT-6)
with concrete call sites + acceptance + sequencing.

**Recommended next-session bundle** (use bundle mode per ADR-0118 D6;
the next /continue should add an `## Active bundle` section to this
handover with these fields):

- Bundle-ID: `10.E-codegen-IT-1..IT-3`
- Cycles-remaining: `~3`
- Continuity-memo: `try_table dispatch + HandlerEntry registration`
- Exit-condition: `try_table fixture compiles + Builder.entries.len > 0`

Step 1b of the resume procedure routes to bundle-next-step when an
`## Active bundle` section is present + exit-condition not yet met.

## Open questions / blockers

- 10.G-4 (struct ops) — blocked-by GC heap impl
- 10.M-realworld — toolchain-blocked (clang_wasm64 fixture)
- 10.P close gate — user touchpoint by construction (collab review)

## Key refs

- **ADR-0118** (`.dev/decisions/0118_meta_loop_consolidation.md`) —
  this bundle's rationale + 6 axes (D1-D6) + retire/merge ledger
- **Integration plan** (`.dev/phase10_eh_integration_plan.md`) — IT-1..IT-6
- **ROADMAP §10** — phase plan
- **Phase 10 design plan** (`.dev/phase10_design_plan_ja.md`)
- **Phase log** (`.dev/phase_log/phase10.md`)
- **Lesson** `2026-05-26-eh-codegen-foundation-atom-rhythm.md`
  (`e62db476`) — atom-rhythm pattern this bundle's D6 defends
