# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc163 (`42ecb99a`) — **opt-in `--fail-detail`** reliable
  per-assert diagnostic in the wasm-3.0 runner (stdout, all 5 fail
  sites). Finding: the cyc160 per-manifest breakdown + gc return_fail
  counter OVER-COUNT (claim ref_test=2/i31=4, but reliable probe = 0
  for both — fully fixed by c161/c162). True gc residuals: array=3
  (array.8 instantiate-fail cascade) + type-subtyping=5. No
  count/behaviour change (gc 335, exit 0, 0 panics). cyc162 abstract
  subtyping (+15); cyc161 externref args (+58). **gc 62→335** session.
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

## Active task — cycle 164: array.8 instantiate-fail (true gc residual) — **NEXT**

Per the reliable `--fail-detail` probe (run:
`<bin> test/spec/wasm-3.0-assert --fail-detail`), the TRUE gc return
residuals are array=3 + type-subtyping=5 (ref_test/i31 are clean; the
breakdown's claims there are phantom over-counts).

- **array.8** (`zwasm run gc/array/array.8.wasm` → "decode/validate
  failed"): array-of-arrays module. `(elem $e (ref $bvec) (array.new
  $bvec …) (array.new_fixed $bvec …))` — a passive elem segment with a
  **concrete-array reftype** `(ref $bvec)` + **array.new/array.new_fixed
  const-expr ITEMS**; `array.new_elem $vec $e` builds an array of those.
  Investigate decodeElement: does it handle a concrete-ref elem reftype
  + non-ref.func const-expr items? Likely the decode gap. Fixing
  array.8 recovers its get/set_get/len cascade (3).
- **type-subtyping (5)**: 3 setup-cascade + 2 real `run exp=1 got=0`
  (D-198 rec-group adjacent; deeper).
- **i31.3/i31.4 (deferred)**: table-with-init-expr decode (`0x40 0x00`
  form) + const-expr global.get-of-import. The const-expr global.get
  patch alone is non-observable (reverted cyc163) — land WITH the
  table-init-expr feature for an observable delta.
VERIFY full test-spec + exit-code + panic grep (cyc150 lesson; DIRECT
binary; use `--fail-detail` for per-assert truth, NOT the breakdown).
No regression to 335 return / 88 trap / 57 invalid / 393 multi-mem.

## Larger §10 work (later bundles)

- **funcrefs** return 32/39 — 1 externref-elem (runner externref-arg) +
  `resolveFuncrefGlobals` (off spec-corpus path). **10.P close gate** =
  user touchpoint by construction.

## Spec runner observable (cycle-163, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=335/407 trap=88/100 invalid=57/60 malformed=1/1 skip=20  ← 10.G c163
[multi-memory       ] return=393/407 trap=238/238  ← cyc141 rt.datas fix
```

> Per-manifest fail counts via `--fail-detail` (reliable) not the
> breakdown: real gc residuals = array(3) + type-subtyping(5).

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
