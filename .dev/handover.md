# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `aa1c53e6` — frame_teardown.Params.uses_runtime_ptr fix
  (10.TC emit-body cycle 4; foundation for x86_64 wire-up).
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
- **Cycles-remaining**: ~3
- **Continuity-memo**: cycles 1-4 landed. Cycle 1 (`c2039bbb`):
  `CallFixup.is_tail` + arm64 linker B/BL dispatch. Cycle 2
  (`4d0e20f1`): `arm64/op_tail_call.emitDirectTailJump` helper.
  Cycle 3 (`b03545fe`): arm64 `return_call.emit` wired
  end-to-end via `emitDirectReturnCall(ctx, ins)` orchestrator
  (marshal → MOV X0,X19 → frame_teardown → emitDirectTailJump).
  `EmitCtx.frame_bytes` plumbed; `op_call.marshalCallArgs` pub
  via SIBLING-PUB; e2e fixture in linker.zig (`fn0 return_call
  fn1 returns 7`) green on Mac aarch64. Cycle 4 (`aa1c53e6`):
  `frame_teardown.Params.uses_runtime_ptr` plumbed + x86_64
  emits POP R15 (mirror of regular epilogue minus RET) —
  latent bug fix that unblocks the x86_64 cycle 5 mirror.
- **Exit-condition**: x86_64 SysV mirror of cycle 3 wired
  end-to-end (JMP rel32 opcode at emit + emitDirectReturnCall
  + same e2e fixture green on Linux x86_64) AND `return_call_
  indirect` / `return_call_ref` arm64+x86_64 wired with at
  least one e2e fixture each.
- **Next cycle (cycle 5)**: x86_64 SysV mirror end-to-end.
  Pre-reqs (x86_64 already has): EmitCtx.frame_bytes,
  EmitCtx.uses_runtime_ptr, op_call.marshalCallArgs pub.
  Sub-steps: (a) `x86_64/op_tail_call.zig` gains
  `emitDirectTailJump(allocator, buf, call_fixups,
  target_func_idx)` = emit `encJmpRel32(0)` (5-byte 0xE9 +
  disp32=0) + append CallFixup{is_tail=true}. Linker's
  patchRel32 preserves the opcode byte. (b) Same file gains
  `emitDirectReturnCall(ctx, ins)`: marshal args →
  emitLoadCalleeRtSameModule (MOV RDI,R15) →
  frame_teardown.emit(.{ frame_bytes, uses_runtime_ptr }) →
  emitDirectTailJump. (c) Add `.return_call` to
  `x86_64/usage.zig::usesRuntimePtr` whitelist (return_call's
  MOV RDI,R15 reads R15 — D-180 lesson). (d) Add
  `.return_call` dispatch arm to `x86_64/emit.zig` (delegate
  to `op_return_call.emit`; set dead_code=true). (e) Ungate
  the linker.zig e2e test (replace mac-only guard with both-
  host guard). Verify both Mac aarch64 + Linux x86_64 SysV
  green via 3-host loop.

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
