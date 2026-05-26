# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `73187e6f` — D-185 closed; arm64 return_call_indirect
  re-applied with arm64/x86_64 op_tail_call imports flipped from
  shared facade to sibling frame_teardown (host-dispatch bug fix).
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
- **Continuity-memo**: cycles 1-5 + cycle 7 (D-185 investigation
  + fix) landed. Same-module direct `return_call` complete on
  both arches. Cycle 6 first attempt (`99d10707`) reverted at
  `aa6f3928` due to ubuntu @divExact panic. Cycle 7 (`73187e6f`)
  diagnosed via D-185 probes: shared `frame_teardown` facade is
  host-dispatched (`builtin.target.cpu.arch`) so arm64 emit on
  x86_64 host wrote 1 byte (POP RBP) instead of 4 (LDP), mis-
  aligning the byte stream. Fix: arm64/op_tail_call.zig +
  x86_64/op_tail_call.zig import sibling frame_teardown directly.
  Cycle 6's arm64 return_call_indirect re-applied with the fix.
  D-185 closed; lesson `2026-05-26-shared-facade-host-dispatched-
  cross-arch-byte-test` filed.
- **Exit-condition**: x86_64 SysV mirror of cycle 3 wired
  end-to-end (JMP rel32 opcode at emit + emitDirectReturnCall
  + same e2e fixture green on Linux x86_64) AND `return_call_
  indirect` / `return_call_ref` arm64+x86_64 wired with at
  least one e2e fixture each.
- **Next cycle (cycle 8)**: x86_64 `return_call_indirect` mirror.
  Sub-steps: (a) `x86_64/op_tail_call.zig` gains
  `emitIndirectReturnCall(ctx, ins)` mirroring arm64 shape —
  pop idx, marshal args, bounds check via cind_bounds_fixups
  (CMP + Jcc rel32 trap), sig check via cind_sig_fixups, MOV
  R11 ← [funcptr_base + idx*8], MOV RDI ← R15, frame_teardown
  (sibling import, NOT shared facade — D-185 lesson),
  emitTailJump(R11). Restrictions mirror arm64: table_idx==0,
  results.len<=2. (b) Wire x86_64 ops stub to delegate; set
  ctx.dead_code.* = true. (c) Add to collected_x86_64_ctx_ops
  (count 395 → 396; bump assertion). (d) Add `.return_call_
  indirect` to x86_64 usesRuntimePtr whitelist. (e) Mirror
  byte-snapshot test (will run cross-arch so the D-185 fix
  is the structural defense against regression).

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
