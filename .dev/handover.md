# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 98 (`9f98c9de`) — subtype-aware
  `opBrOnNonNull` label-type match (narrowed reftype flows to
  branch target per Wasm 3.0 §3.3.10.9). Spec-correct but corpus
  delta=0 (3rd consecutive 0-delta cycle).
- Cycles 91-97 before: ValType pivot; parser typed-funcref bytes;
  narrowing; subtype popExpect / expectFrameEndTypes.

## Yield-taper note (per `lessons/2026-05-28-yield-taper-pacing.md`)

Bundle 10.R-funcrefs-tail cycles 96/97/98 all shipped spec-correct
subtype-aware fixes with zero corpus delta. Per-module failures
involve multiple cascading issues; chipping at validator
strictness sites isn't moving function-references return pass-rate.
Highest-leverage pivot: 10.E ADR-0120 Cycles 2-5 (throw.emit +
try_table.emit catch landing-pad + catch_ref reification) unlock
~30 EH directives directly. Bundle 10.R-funcrefs-tail paused;
forward path 10.R-funcrefs-tail = bucket-3-stop-equivalent until
either user touchpoint OR cycle-finish on 10.E gives related
unblock signal.
- Cycle 90 (`6e5e7e53` + `510eca36` + `d6b187f8`) before that:
  D-179 baker swap; ADR-0120 Accept + Cycle 1 impl; ADR-0123 Accept
  + Cycle 1 substrate.
- Mac aarch64 test-all + lint green.

## Active bundle

- **Bundle-ID**: 10.E-payload-prop-v2 (ADR-0120 Cycles 2-5 per
  ADR-0120 Consequences §1; ADR-0120 Cycle 1 substrate landed
  at `510eca36`).
- **Cycles-remaining**: ~4
- **Continuity-memo**: ADR-0120 Cycle 1 (Runtime field +
  tag_param_slot_counts thread) landed cycle 90. Cycle 2 of
  bundle: throw.emit reads `tag_param_slot_counts[tag_idx]` and
  emits the pop+STR sequence to write payload values to
  `[runtime_ptr + eh_payload_ptr_off + i*8]` (arm64 first,
  x86_64 bundled same cycle per arch-symmetry rhythm). Cycle 3:
  try_table.emit catch-landing-pad prologue (LDR + push vreg
  per slot). Cycle 4: catch_ref / catch_all_ref via
  zwasm_reify_exnref helper. Cycle 5: spec-corpus runner wiring
  + close 10.E.
- **Exit-condition**: function-references unchanged for now
  (paused per yield-taper note); EH `return=34 trap=2
  exception=4` go from currently 0-pass to ≥30 pass.
- **Paused**: 10.R-funcrefs-tail (resume when 10.E lands OR
  external signal).
- **Exit-condition**: function-references spec corpus assert_return
  pass-rate ≥ 30/39 (currently 3/39); call_ref + return_call_ref
  green-baked + validated; 0 ParseFailed for any
  function-references module.

## Active task — cycle 99: ADR-0120 Cycle 2 — throw.emit payload pop+STR (arm64 + x86_64 bundled)

Per ADR-0120 Consequences §1 Cycle 2: implement throw.emit (both
arches in same chunk per arch-symmetry rhythm). Reads
`tag_param_slot_counts[tag_idx]` from EmitCtx (Cycle 1 substrate
already threaded); pops N slots from operand stack; emits N STRs
into `[runtime_ptr + eh_payload_ptr_off + i*8]`; then sets
`eh_payload_len = N` at the corresponding offset; then preserves
existing tag_idx → argreg-0 MOV + BLR/CALL trampoline.

Smallest red test:
`test "throw + catch_ with i32 payload returns 88 (cycle 99 throw-emit)"`
in arm64 / x86_64 op tests. Currently `throw + catch_all returns
42` IT-6 test passes (N=0 path); add N=1 i32 payload variant.

After cycle 99 lands, cycles 100-102 of ADR-0120 bundle:
- Cycle 3: try_table.emit catch-landing-pad LDR + push vreg.
- Cycle 4: catch_ref / catch_all_ref reify via
  zwasm_reify_exnref runtime helper.
- Cycle 5: spec-corpus runner wiring + close 10.E.

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
