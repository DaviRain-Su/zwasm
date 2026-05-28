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

- **None.** Cycle-99 inspection found that ADR-0120 Cycles 2-5
  (throw.emit payload pop+STR + try_table.emit catch landing pad
  + catch_ref reify + spec-corpus wiring) ALREADY LANDED as the
  prior 10.E-payload-prop bundle (closed at D-182 discharge,
  commit `7987f136`-class). The IT-6 test
  `runI32Export: throw + catch_ with i32 payload returns 88`
  passes; arm64 + x86_64 throw.emit + catch landing-pad fully
  wired against JitRuntime's inline `[16]u64` eh_payload_buf.
- The cycle-90 ADR-0120 revise (`[]u64` pre-sized at instantiate)
  changed the INTERP-side `Runtime.eh_payload` shape; the JIT-
  side `JitRuntime.eh_payload_buf [16]u64` stayed inline (no
  user-observable difference for v0.1 scope).
- EH spec corpus (`return=34 trap=2 exception=4`) all-fail is
  gated on D-192 (cross-module register: try_table.1.wasm imports
  test::e0 tag + test::throw func from try_table.0.wasm; runner
  registry not wired) + exnref ValType extension (D-188 prereq).
  These are NOT cycle-99-scope.
- **Exit-condition**: function-references spec corpus assert_return
  pass-rate ≥ 30/39 (currently 3/39); call_ref + return_call_ref
  green-baked + validated; 0 ParseFailed for any
  function-references module.

## Bucket-3 stop framing — autonomous prep exhausted at session end

All forward work that meaningfully advances spec runner observable
is gated on one of:

1. **D-192 cross-module register substrate** — EH spec corpus
   gated. ~30 EH directives. Substrate exists (D-195(b) runner
   register-arm shipped), but extension to tag + func cross-module
   binding for `try_table.1.wasm`-style fixtures is structural
   work (~3-5 cycles).
2. **Exnref ValType extension** (D-188 prereq) — try_table.8/10
   + `catch_ref`/`catch_all_ref` validator semantics require
   exnref as a first-class ValType variant. Touches Zone-1 ValType
   union (post-cycle-90 widen), validator type-stack, interp
   payload propagation. ADR-grade per ROADMAP §18.2. ~3-5 cycles.
3. **Concrete typed-funcref opRefFunc push (non-null)** — Wasm
   3.0 §3.3.10.10 requires `ref.func $f` yields `(ref $sig)`
   (non-null concrete typed). Needs func_typeidxs plumbing into
   validator. Likely 1 cycle but corpus-effect needs validation.
4. **BadBlockType for typed-ref block result types** — block
   instr prefix encoder doesn't accept `0x63`/`0x64` typed-ref
   bytes as block result types. ~1 cycle.

Recent autonomous cycles (96-98) shipped 3× structurally-correct
subtype-aware fixes with 0 corpus delta — further isolated fixes
unlikely to compound without one of the gates above.

**Session-summary observable** (cycle 90 start → cycle 99 end):

```
Before (cycle 81):  total 2000 directives baked; gc=0
After  (cycle 99):  total 2349 directives baked (+349 = +17%)
                    gc 568 directives now visible (impl=0%, surface=100%)
                    assert_invalid pass=193 fail=1
```

Material structural changes shipped this session:

- D-179 baker swap (wabt → wasm-tools) — GC corpus unlocked.
- ADR-0120 Accepted + Cycle 1 substrate (`eh_payload []u64` +
  slot_counts) — Cycles 2-5 already shipped previously.
- ADR-0123 Accepted + Cycles 1-5 (partial) — ValType pivot to
  union(enum); 30+ files migrated; parser typed-funcref bytes;
  validator narrowing + subtype awareness on popExpect /
  expectFrameEndTypes / opBrOnNonNull. 3 function-references
  modules newly parse.
- Audit cohort follow-through (D-186 reactivation, ADR backfills,
  SKILL.md split, lint scripts, gate wiring).
- Lessons filed for future cycles (yield-taper, corpus-expansion-
  exhausted, funcrefs-tail-error-classes).

Autonomous loop not re-armed — bucket-3 stop until user
touchpoint (next ADR draft / impl direction / wait-on-external).

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
