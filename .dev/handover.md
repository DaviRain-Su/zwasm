# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 93 (`3593e568`) — **ADR-0123 Cycle 4 landed**:
  validator narrows `RefType.nullable=true → false` on
  ref.as_non_null + br_on_null fall-through. Carve-outs for
  Cycle 5: opBrOnNonNull subtype label-match + opRefFunc
  non-null push (both need subtype-aware popExpect helper).
- Cycles 91/92 before: ValType pivot to union(enum); parser
  0x63/0x64 typed-funcref bytes + module-load typeidx bounds.
- Cycle 90 (`6e5e7e53` + `510eca36` + `d6b187f8`) before that:
  D-179 baker swap; ADR-0120 Accept + Cycle 1 impl; ADR-0123 Accept
  + Cycle 1 substrate.
- Mac aarch64 test-all + lint green.

## Active bundle

- **Bundle-ID**: 10.R-valtype-widen
- **Cycles-remaining**: ~1 (Cycle 4 closed at `3593e568`)
- **Continuity-memo**: ref.as_non_null + br_on_null fall-through
  narrowing done. Cycle 5 (final): call_ref / return_call_ref
  runtime impl per ADR-0123 D3 / D4 + subtype-aware popExpect
  helper that unblocks opRefFunc non-null push + opBrOnNonNull
  label-type subtype match. Bundle exit-condition: spec corpus
  function-references return ≥ 30/39 from currently 0/39.
- **Exit-condition**: function-references spec corpus assert_return
  pass-rate ≥ 30/39 (currently 3/39); call_ref + return_call_ref
  green-baked + validated; 0 ParseFailed for any
  function-references module.

## Active task — cycle 94: call_ref + return_call_ref impl (Cycle 5, bundle close)

Smallest red test:
`test "call_ref: pop funcref + sig check trap → IndirectCallTypeMismatch"`
in `src/instruction/wasm_3_0/call_ref.zig`. Migrate call_ref +
return_call_ref from `NotMigrated` stub to full validate /
interp / emit per ADR-0123 D3 (reuse call_indirect substrate +
runtime null-trap + sig check via ZirInstr.payload typeidx).

Also lands in this cycle:
- Subtype-aware `popExpect` helper that accepts non-null where
  nullable is expected (per spec §3.3.4 subtype rules).
- `opRefFunc` push: switch from `.funcref` (nullable) to
  non-null abstract func ref `RefType.abs(.func, false)` (or
  concrete `RefType.conc(typeidx, false)` if typeidx-plumbing
  through to validator is feasible same-cycle).
- `opBrOnNonNull` label-type subtype match (relaxed eql).

Bundle close requires: function-references corpus assert_return
≥ 30/39 pass (currently 0/39). At close, D-186 retires + ADR-0123
moves from "Accepted" to "Closed (implemented)".

## Larger §10 work (post-bundle)

- **10.E EH payload-prop bundle** (ADR-0120 Cycles 2-5): throw.emit
  pop+STR; try_table.emit catch landing-pad LDR+push; catch_ref
  reification helper; spec corpus runner wiring. ~30 EH directives
  flip to pass.
- **10.G WasmGC ZIR ops** — D-179 unblocked at the bake layer;
  impl distance is large (ZIR op set + heap impl + subtype lattice
  reuse ADR-0123 RefType shape).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-90 baker swap)

```
[memory64           ] return=337(all pass) trap=205(all pass) invalid=83
[tail-call          ] return=71  trap=7    invalid=24(pass=23 fail=1)
[exception-handling ] return=34(fail) trap=2(fail) invalid=7(pass) exception=4(fail)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[gc                 ] return=407(fail=384) trap=100(fail=100) invalid=60(pass) malformed=1(pass)  ← NEW
[multi-memory       ] return=407(pass=371 fail=36) trap=238(pass=237 fail=1) invalid=2 malformed=2 skip=56
[wasm-3.0-assert] total: 71 manifests, 2349 directives
```

## Open questions / blockers

- ADR-0120 / ADR-0123 — both Accepted; impl bundles autonomous.
- D-179 — DISCHARGED.
- D-186 — discharge path unblocked by ADR-0123 D4; awaits cycle 5
  of 10.R-valtype-widen bundle.
- D-195 (function-references corpus gates) — sub-gap (a) unblocked
  by ADR-0123 Cycle 3; sub-gap (b) cross-module register remains.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0120 (Accepted — EH payload), ADR-0123 (Accepted — typed-ref).
- `.dev/lessons/2026-05-28-spec-corpus-expansion-exhausted.md`
  (cycle-88 survey that surfaced these gates).
- ROADMAP §10; `.dev/phase_log/phase10.md`.
