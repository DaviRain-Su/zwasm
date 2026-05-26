# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `c2039bbb` — CallFixup.is_tail + linker B/BL dispatch
  (10.TC emit-body cycle 1 of the active bundle).
- **ROADMAP §10 progress**: 7/13 DONE (10.0/10.C9/10.J/10.F/
  10.Z/10.D/10.T), 4 IN-PROGRESS (10.M/10.R/10.TC/10.E with
  10.E core substantively done), 2 Pending (10.G/10.P).
- **Active debt rows**: 16 — all `blocked-by:` with named
  structural barriers (Phase 11 / toolchain / GC / v0.2). Zero
  `now`-status rows.
- **D-180 structural defenses STILL IN PLACE** (x86_64
  `usesRuntimePtr` whitelist drift detector + test discipline
  §4 + lesson).

## Active bundle

- **Bundle-ID**: 10.TC-emit-body
- **Cycles-remaining**: ~6
- **Continuity-memo**: foundation cycle 1 landed (CallFixup gains
  `is_tail`; arm64 linker dispatches B vs BL; x86_64 emit owns
  the opcode byte; 2 unit tests cover both branches). Helpers
  available from 10.TC-3a..3e: `op_tail_call.emitTailJump`,
  `op_tail_call.emitLoadCalleeRtSameModule`, `tail_target_gpr`,
  `frame_teardown.emit` (per-arch via shared facade). Refinement
  of ADR-0112 D4 (not deviation): same-module direct uses
  B+CallFixup{is_tail=true} (1 instr); cross-module/indirect/ref
  use BR X16+literal-pool (D4 prescribed shape).
- **Exit-condition**: `return_call N` arm64 emit body wired
  end-to-end (marshal args → MOV X0,X19 → frame_teardown → B
  fixup), driven by a spec fixture from
  `test/spec/wasm-3.0-assert/tail-call/return_call/return_call.0.wasm`
  through `cli_run.runWasmCaptured` returning the expected i32
  on Mac aarch64. Cross-arch (x86_64 SysV mirror) lands as a
  follow-on bundle cycle. The bundle closes only when all 3 ops
  (return_call / return_call_indirect / return_call_ref) emit
  end-to-end on Mac aarch64 with one spec fixture each.
- **Next cycle (cycle 2)**: wire arm64 `return_call.emit` body —
  reuse `op_call.marshalCallArgs`, then `emitLoadCalleeRtSameModule`,
  then `frame_teardown.emit`, then append `B 0` placeholder +
  `CallFixup{byte_offset, target_func_idx=ins.payload, is_tail=true}`.
  Add helper `op_tail_call.emitDirectTailJump` that owns the
  placeholder+fixup append. Drive by a new spec-fixture-shaped
  unit test in `test/spec/` or `src/engine/codegen/arm64/`.

## Session highlights (prior session; for handoff context)

- 4 debts closed end-to-end (D-181/D-182/D-183/D-184).
- 1 bundle closed (10.E-payload-prop; ADR-0120 5 cycles).
- 3 new lessons (`2026-05-28-eh-catch-landing-pad-per-clause-prelude`,
  `2026-05-28-x86_64-prologue-rbp-r15-unwinder-mismatch`,
  `2026-05-28-x86_64-uses-runtime-ptr-eh-gap`).
- 6 JIT e2e EH regressions + 1 interp tail-call chain test +
  dispatcher unit tests + toModuleRelativePc contract pin.

## Next candidates (after 10.TC-emit-body bundle closes)

- **10.E spec corpus runner** — `spec_assert_runner_wasm_3_0.zig`
  is a 130-line skeleton (enumerate-and-count). Adding actual
  assert_return / assert_trap / assert_exception execution is
  multi-cycle.
- **10.G WasmGC** — large multi-cycle bundle; design plan +
  ADRs (0115/0116/0117) already shipped.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).
- **10.E follow-on**: c_api tag accessors, cross-module EH
  propagation (v0.2), eh_frequency_runner bench scaffolding
  (Phase 8b).

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0017, ADR-0026, ADR-0111, ADR-0112 (tail-call design;
  governs the active bundle), ADR-0113 §A (terminator class),
  ADR-0114 D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.TC.
- Lessons (Phase 10 EH cycle): see
  `.dev/lessons/INDEX.md` entries 2026-05-26..2026-05-28 (5 EH
  lessons total).
