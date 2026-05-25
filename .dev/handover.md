# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)
- **Meta-pivot bundle SHIPPED 2026-05-26** (ADR-0118):
  `0b0a514d..2ce59032`.
- **10.D = CLOSED 2026-05-25**: 全 7 ADR (0111-0117) Accepted.
- **10.M sub-chunks 1..fixture-2 = SHIPPED**.
- **10.R sub-chunks 1..5 = SHIPPED**.
- **10.TC-1 = SHIPPED** (`a83e095f`).
- **10.G-i31-ops / 10.G-2 / 10.G-3 = SHIPPED**.
- **10.E interp side = COMPLETE**.
- **10.E codegen IT-1..IT-5 = SHIPPED**:
  - IT-1 (`c3424788`): EmitCtx.exception_table_builder wiring
  - IT-2 (`2d938570`): try_table emit body — HandlerEntry per
    catch, pc_end patched at matching `end`
  - IT-3 (`466674b7`): throw / throw_ref emit as unconditional
    trap (dispatcher CALL deferred to IT-6)
  - IT-4 (`5b75bee5`): linker populates per-Instance
    CodeMap entries on JitModule
  - IT-5 (`14fafdc6`): CompiledWasm.exception_table aggregates
    per-function HandlerEntry slices with module-relative pcs

## ROADMAP §10 progress

- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS (4): 10.M (7/8) / 10.R (5/5; gated on 10.G) /
  10.TC (codegen + cross-module + spec corpus 残) /
  10.E (codegen integration IT-6 残)
- Pending (3): 10.G / 10.P (close gate)

## Active task — Phase 10.E IT-6

Next continuous chunk picks up at **IT-6** per
`.dev/phase10_eh_integration_plan.md` §IT-6 — per-arch
`zwasm_throw` assembly trampoline glue. The trampoline captures
throw-site FP + LR (X29 / X30 on arm64; RBP / saved-RIP on
x86_64), calls `shared/zwasm_throw.dispatchThrow(table,
code_map, throw_site, max_depth)`, and on the result either
JMPs to the landing pad (via `sp_restore.emitSpRestoreFull`) or
sets `trap_flag=1` and unwinds via the standard trap epilogue.

This is the load-bearing piece: once IT-6 ships, throw / throw_ref
actually call dispatchThrow instead of trapping unconditionally
(the IT-3 minimum shape). Realistic scope: IT-6 may itself need
to split into IT-6a (assembly stub design + `naked` Zig vs `.s`
ADR decision) and IT-6b (per-arch impl + integration with
op_throw.emit replacing the trap-only path). The integration
plan §IT-6 cites the choice between pure-Zig + `naked` attribute
and per-arch `.s` files as an open design question.

After IT-6: row 10.E flips DONE; spec corpus fixture run
(wasm-3.0-assert/exception-handling/) becomes runnable.

## Open questions / blockers

- 10.G-4 (struct ops) — blocked-by GC heap impl
- 10.M-realworld — toolchain-blocked (clang_wasm64 fixture)
- 10.P close gate — user touchpoint by construction
- IT-6 design choice: pure-Zig `naked` fn vs per-arch `.s` file
  for the trampoline entry stub (`.dev/phase10_eh_integration_plan.md`
  §IT-6 "Open questions for user collab")
- IT-2 HandlerEntry.landing_pad_pc currently holds the raw
  relative br-depth (placeholder); IT-6 resolves it
- IT-4 CodeMap.Entry.frame_bytes is a 0 placeholder; IT-6
  SP-restore path populates it

## Key refs

- **Integration plan** (`.dev/phase10_eh_integration_plan.md`) —
  IT-1..IT-6 (IT-1..IT-5 shipped; IT-6 next; last in chain)
- **ADR-0114** (EH design)
- **ADR-0118** (`.dev/decisions/0118_meta_loop_consolidation.md`)
- **ROADMAP §10**
- **Phase log** (`.dev/phase_log/phase10.md`)
- **Lesson** `2026-05-26-eh-codegen-foundation-atom-rhythm.md`
  (`e62db476`)
