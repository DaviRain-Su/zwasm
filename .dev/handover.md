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

## ROADMAP §10 progress

- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS (4): 10.M (7/8) / 10.R (5/5; gated on 10.G) /
  10.TC (codegen + cross-module + spec corpus 残) /
  10.E (codegen IT-6 trampoline impl 残)
- Pending (3): 10.G / 10.P (close gate)

## Active bundle

- **Bundle-ID**: `10.E-codegen-IT-6`
- **Cycles-remaining**: `~1-2` (trampoline impl + op_throw retarget)
- **Continuity-memo**: ADR-0119 Accepted (`213df2f2`); spike
  empirically validated `callconv(.naked)` semantics on all 3
  hosts. Trampoline impl is now unblocked.
- **Exit-condition**: end-to-end `throw 0 / catch_all 0` fixture
  compiles + runs + lands at the catch block (per integration
  plan §IT-6 acceptance).

Next /continue resume picks up the **trampoline impl** —
create `src/engine/codegen/{arm64,x86_64}/throw_trampoline.zig`
per ADR-0119 Decision §. Body per ADR-0114 D6 sequence:
capture FP+LR into ThrowSite stack record, marshal Runtime ptr
+ tag_idx + payload into argregs, CALL
`shared/zwasm_throw.dispatchThrow`, branch on UnwindResult:
- `.handler`: `sp_restore.emitSpRestoreFull` (uses
  CodeMap.Entry.frame_bytes from IT-6 prep) + BR/JMP to
  `landing_pad_pc` (resolved by IT-6 prep landing_pad fixup).
- `.uncaught`: standard trap-stub epilogue (set trap_flag=1,
  RET).

Then retarget `op_throw.emit` + `op_throw_ref.emit` to CALL
the trampoline (replacing the IT-3 unconditional-trap branch).
Address load: either `@intFromPtr(&zwasmThrowTrampoline)` via
literal pool (arm64) / RIP-rel MOVABS (x86_64), OR a Runtime
field set at instance init time — choose at impl time.

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
