# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)
- **Meta-pivot bundle SHIPPED 2026-05-26** (ADR-0118): commits
  `0b0a514d..2ce59032`.
- **10.D = CLOSED 2026-05-25**: 全 7 ADR (0111-0117) Accepted.
- **10.M sub-chunks 1..fixture-2 = SHIPPED**.
- **10.R sub-chunks 1..5 = SHIPPED**: gated on 10.G.
- **10.TC-1 = SHIPPED** (`a83e095f`).
- **10.G-i31-ops / 10.G-2 / 10.G-3 = SHIPPED**.
- **10.E interp side = COMPLETE**.
- **10.E codegen IT-1 = SHIPPED** (`c3424788`).
- **10.E codegen IT-2 = SHIPPED** (`2d938570`): try_table.emit
  populates HandlerEntry per catch clause; pc_end patched at
  matching `end`; `EmitOutput.exception_handlers` carries the
  per-function slice for IT-5 to fold into CompiledWasm.

## ROADMAP §10 progress

- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS (4): 10.M (7/8) / 10.R (5/5; gated on 10.G) /
  10.TC (codegen + cross-module + spec corpus 残) /
  10.E (codegen integration IT-3..IT-6 残)
- Pending (3): 10.G / 10.P (close gate)

## Active bundle

- **Bundle-ID**: `10.E-codegen-IT-1..IT-3`
- **Cycles-remaining**: `~1` (IT-1 + IT-2 shipped; IT-3 remains)
- **Continuity-memo**: throw / throw_ref emit body — pop payload
  values, marshal tag_idx + payload base/length into argregs,
  emit CALL `zwasm_throw` fixup, branch on UnwindResult (.handler
  → JMP landing_pad_pc via sp_restore.emitSpRestoreFull;
  .uncaught → trap stub). Per ADR-0114 D6 + integration plan §IT-3.
- **Exit-condition**: minimal `throw 0 () catch_all` fixture
  compiles + runs, exiting via the trap path (no handler installed
  yet — that arrives at IT-6 with the trampoline glue).

Next /continue resume routes to IT-3 (throw / throw_ref bodies in
`src/engine/codegen/{arm64,x86_64}/ops/wasm_3_0/throw{,_ref}.zig`)
per `.dev/phase10_eh_integration_plan.md` §IT-3.

## Open questions / blockers

- 10.G-4 (struct ops) — blocked-by GC heap impl
- 10.M-realworld — toolchain-blocked (clang_wasm64 fixture)
- 10.P close gate — user touchpoint by construction
- IT-2 landing_pad_pc currently holds the raw relative br-depth
  (placeholder); IT-4 resolves to a JIT byte offset

## Key refs

- **Integration plan** (`.dev/phase10_eh_integration_plan.md`) —
  IT-1..IT-6 (IT-1 + IT-2 shipped; IT-3 next)
- **ADR-0118** (`.dev/decisions/0118_meta_loop_consolidation.md`)
- **ROADMAP §10**
- **Phase log** (`.dev/phase_log/phase10.md`)
- **Lesson** `2026-05-26-eh-codegen-foundation-atom-rhythm.md`
  (`e62db476`)
