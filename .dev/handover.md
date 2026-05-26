# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `aa6f3928` — revert pair for 10.TC-emit-body cycle 6
  (arm64 return_call_indirect panicked on Linux x86_64 SysV ubuntu
  with `@divExact` alignment failure; D-185 filed for root-cause).
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
- **Cycles-remaining**: ~4 (cycle 6 reverted; investigation cycle
  inserted before re-attempt)
- **Continuity-memo**: cycles 1-5 landed (same-module direct
  `return_call` complete on both arches). Cycle 6 (`99d10707` +
  `8d1b7e7a`) attempted arm64 `return_call_indirect` but ubuntu
  Linux x86_64 panicked with `@divExact` alignment failure in
  the cind_bounds_fixups trap-stub patching loop. Reverted via
  `b6d669b7` + `aa6f3928` per Step 0.7 mandate. Same code passes
  full clean rebuild on Mac aarch64; the failure is heisenbug-
  class (host-conditional alignment divergence). Filed D-185.
- **Exit-condition**: x86_64 SysV mirror of cycle 3 wired
  end-to-end (JMP rel32 opcode at emit + emitDirectReturnCall
  + same e2e fixture green on Linux x86_64) AND `return_call_
  indirect` / `return_call_ref` arm64+x86_64 wired with at
  least one e2e fixture each.
- **Next cycle (cycle 7 — D-185 investigation)**: probe the
  Linux x86_64 alignment divergence BEFORE re-attempting
  return_call_indirect. Per `investigation_discipline.md` §1:
  each cycle should land one permanent diagnostic primitive
  rather than throwaway probes. Approach: cherry-pick the
  cycle 6 diff (`99d10707`), then add `std.debug.print` at
  every `cind_*_fixups.append` site in arm64/op_call.zig +
  emitIndirectReturnCall printing `buf.items.len % 4`, plus
  print `@sizeOf(ZirInstr)` / `@alignOf(ZirInstr)` once at
  compile() entry. Run `bash scripts/run_remote_ubuntu.sh
  test` and `zig build test` locally; compare the cind-fixup
  byte_offsets across hosts. Leading hypotheses from D-185:
  (3) ZirInstr layout host-divergent (extra-field padding);
  (4) regalloc-slot reg-vs-spill branch host-divergent. Probe
  distinguishes the two. Root-cause → cycle 8 ships the fix.

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
