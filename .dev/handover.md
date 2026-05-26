# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)
- **10.D = CLOSED 2026-05-25**.
- **10.M sub-chunks 1..fixture-2 = SHIPPED**.
- **10.R sub-chunks 1..5 = SHIPPED**.
- **10.TC-1 = SHIPPED** (`a83e095f`).
- **10.G-i31-ops / 10.G-2 / 10.G-3 = SHIPPED**.
- **10.E interp side = COMPLETE**.
- **10.E codegen IT-1..IT-5 = SHIPPED** (`c3424788`, `2d938570`,
  `466674b7`, `5b75bee5`, `14fafdc6`).
- **10.E IT-6 prep SHIPPED**: frame_bytes thread (`9ac268f1`),
  landing_pad_pc forward fixup (`18b2a077`), ADR-0119 draft
  (`e725bce7`), spike-validated flip to Accepted (`213df2f2`).
- **10.E IT-6 cycle 3a SHIPPED** (`14b32f74`): trampoline
  scaffolding under `shared/throw_trampoline.zig` (naked fn,
  trap-only body).

## ROADMAP §10 progress

- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS (4): 10.M (7/8) / 10.R (5/5; gated on 10.G) /
  10.TC (codegen + cross-module + spec corpus 残) /
  10.E (codegen IT-6 trampoline impl 残)
- Pending (3): 10.G / 10.P (close gate)

## Active bundle

- **Bundle-ID**: `10.E-codegen-IT-6`
- **Cycles-remaining**: `~2` (op_throw retarget + dispatchThrow
  integration in trampoline body)
- **Continuity-memo**: ADR-0119 Accepted (`213df2f2`); trampoline
  scaffolding shipped (`14b32f74`) under
  `src/engine/codegen/shared/throw_trampoline.zig` with trap-only
  body. Symbol exists + is testable via inline-asm wrapper.
- **Exit-condition**: end-to-end `throw 0 / catch_all 0` fixture
  compiles + runs + lands at the catch block (per integration
  plan §IT-6 acceptance).

Next /continue resume picks up **cycle 3b — op_throw retarget**:
update arm64 + x86_64 `op_throw.emit` (and `throw_ref`) to emit
the address-load + BLR/CALL sequence targeting
`@intFromPtr(&zwasmThrowTrampoline)`, followed by the B/JMP
fallback to the function trap stub (existing IT-3 path stays
as the "trampoline returned" continuation). Address-load
recipe choice:
- arm64: MOVZ/MOVK chain (4 instr, 16 bytes) into X16, then BLR X16.
- x86_64: MOVABS imm64 into RAX (10 bytes), then CALL RAX.

Cycle 3c (final): replace the trampoline's trap-only body with
the full dispatchThrow integration per ADR-0114 D6 — capture
FP+LR into ThrowSite, CALL `shared/zwasm_throw.dispatchThrow`,
branch on UnwindResult (`.handler` → sp_restore + JMP to
landing_pad_pc; `.uncaught` → keep current trap_flag set).

## Open questions / blockers

- 10.G-4 (struct ops) — blocked-by GC heap impl
- 10.M-realworld — toolchain-blocked (clang_wasm64 fixture)
- 10.P close gate — user touchpoint by construction

## Key refs

- **ADR-0119 Accepted** (`213df2f2`,
  `.dev/decisions/0119_eh_trampoline_naked_zig.md`)
- **Spike** `private/spikes/p10-it6-naked-trampoline/` —
  Status: merged-into-prod (zero-prologue empirical evidence,
  per-host disasm in README)
- **Integration plan** (`.dev/phase10_eh_integration_plan.md`)
- **ADR-0114** (EH design — D6 specifies the trampoline shape)
- **ROADMAP §10**
- **Phase log** (`.dev/phase_log/phase10.md`)
- **Lesson** `2026-05-26-eh-codegen-foundation-atom-rhythm.md`
  (`e62db476`)
