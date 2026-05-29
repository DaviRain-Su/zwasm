# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc161 (`f45ff26f`) — **bind host externref args**
  (`ref.extern N`) in the wasm-3.0 manifest parser. parsePayload
  rejected externref → `invoke init externref:0` was skipped → init()
  no-op'd → ref_test/ref_cast/br_on_cast/br_on_cast_fail tables null.
  Sentinel binding unlocks the cascade: **gc return 262→320 (+58)**
  (ref_test 33→2, br_on_cast/_fail 10→0 each, ref_cast 7→0), trap
  84→88, invalid 57 held; **funcrefs 32→34**. exit 0, 0 panics.
  cyc160 per-manifest breakdown infra; cyc159 ref.func const-expr.
  **gc 62→320** across the session.
- cyc147-148 **ADR-0125 packed COMPLETE** (A union rename → B-validate
  decode → B-exec get_s/u): gc return 62→116, trap 18→54, ValidateFailed
  27→14, invalid 57 held. cyc146 ADR-0016 M3 + concrete-subtype coercion.
- cyc146 infra (`337eb386`): **ADR-0016 M3** validate self-attribution
  (`compile FAIL: … [fn= off= op=]`, retired op-probe) + concrete→concrete
  subtypeCtx coercion (ValidateFailed 29→27). cyc144/145: GC reftype
  blocktypes + br_on_cast/_fail validate.
- cyc141 array exec + rt.datas production fix (multi-memory +6→393);
  cyc138-140 struct/array const-expr + array.new_data/elem; cyc130-137
  i31/struct/array. gc return 0→…→62, trap 18, multi-memory 393.
- Runner EXECUTES via interp; gc_heap + gc_type_infos + rt.datas all
  materialised at instantiate. Arrays use 8-byte uniform slots
  (type_info.slot_size); data-seg elements are NATURAL width.
- **Bundle 10.E-eh-tail CLOSED** cyc120 (`5db875b0`) — EH corpus FULLY
  GREEN 34/34 (cross-module propagation + caller-frame catch; ADR-0114
  full substrate cyc110–120; D-192 EH clause PROVEN). Lesson
  `eh-cross-module-tag-substrate-scope` has the journey.
- Mac+ubuntu green through cyc142 (`OK (HEAD=a763d44a)`).

## Active bundle

- **Bundle-ID**: 10.G-wasmgc (WasmGC spec corpus — the largest
  remaining §10 gap; follows the CLOSED 10.E EH chain)
- **Cycles-remaining**: open (RTT exec + array bulk ops DONE c149-158;
  next = survey densest remaining gc return-fail cluster)
- **Continuity-memo**: parse + i31 + struct/array narrowing/exec/const-
  expr + packed-validate all DONE (gc return →105). Substrate (don't
  rebuild): `feature/gc/` heap+type_info+i31+collector, struct_ops/
  array_ops registered (api/instance.zig:883-887), StorageType union
  (ADR-0125), ADR-0115/0116/0121/0124. **VERIFY by DIRECT binary run**;
  M3 attributes every compile FAIL (`grep "compile FAIL.*op=0x"`).
- **Exit-condition**: gc return ≥ 90 **EXCEEDED (116 at cyc148)**. Open
  target: maximise return (RTT exec) toward the corpus ceiling.

## Active task — cycle 162: i31 (19 return-fails, #1 remaining lever) — **NEXT**

Post-cyc161 gc breakdown (32 return-fails left): `i31=19`, `array=6+2t`,
`type-subtyping=5+10t (D-198 deep)`, `ref_test=2` (residual precise
eq/struct-on-externalized-host classification — coarse gcAbstractMatch
returns true for eq/any on a host-extern; needs real extern↔any
discrimination, follow-on).

**i31** (gc/raw/i31.wast, 19 fails): i31 has NO externref-arg init, so
this is genuine i31 ref.test/get / i31.new / array-of-i31 behaviour.
SURVEY i31.wast: which exports fail? (per-manifest breakdown localises;
to see per-assert expected-vs-actual either eyeball i31.wast asserts +
run via CLI, or add env-gated FAIL-detail to the runner — note the
cyc161 finding that std.debug.print probes under-report vs the reliable
stdout breakdown). VERIFY full test-spec + exit-code + panic grep
(cyc150 lesson; DIRECT binary). No regression to 320 return / 88 trap /
57 invalid / 393 multi-mem / 34 funcrefs.

## Larger §10 work (later bundles)

- **funcrefs** return 32/39 — 1 externref-elem (runner externref-arg) +
  `resolveFuncrefGlobals` (off spec-corpus path). **10.P close gate** =
  user touchpoint by construction.

## Spec runner observable (cycle-161, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=320/407 trap=88/100 invalid=57/60 malformed=1/1 skip=20  ← 10.G c161
[multi-memory       ] return=393/407 trap=238/238  ← cyc141 rt.datas fix
```

## Open questions / blockers

- D-197: parse/validate/instantiate split DONE cyc127. Specific
  validate-error surfacing is ad-hoc via the cyc143 op-probe (lesson
  `gc-type-subtyping-is-rtt-blocked`); permanent diag emitter = D-197 tail.
- D-192: EH clause PROVEN (EH 34/34). funcrefs clause proven cyc108.

## Key refs

- ADR-0114 (EH `*TagInstance`, IMPLEMENTED cyc110–120); ADR-0115/0116/
  0121 (GC heap + type-info); ADR-0120/0123.
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (full EH journey) + `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
