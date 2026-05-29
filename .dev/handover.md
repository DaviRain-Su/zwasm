# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc168 (`833c19b9`) — **ADR-0126 Phase-10a: structural
  canonical type ids** (materialiseGcTypes computes `canonical_ids[]`)
  + RTT canonical match in `concreteReaches`. Fixes ref_test test-canon:
  **gc return 343→344 (+1)**, trap 90, invalid 57 held; no regression,
  0 panics. Runtime-only (validator/linker canonical match = cyc169).
  cyc167 filed ADR-0126; cyc166 table-init-expr (i31 clean). **gc 62→344**.
- Earlier arc: cyc147-148 ADR-0125 packed (62→116); cyc146 ADR-0016 M3
  validate self-attribution (`compile FAIL [fn= off= op=]`) + subtypeCtx
  coercion; cyc144/145 GC blocktypes + br_on_cast; cyc141 rt.datas fix
  (multi-mem→393); cyc130-140 i31/struct/array + const-expr.
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

## Active task — cycle 169: Phase-10a validator/linker canonical match — **NEXT**

Runtime canonical match DONE (c168, test-canon). Now extend canonical-id
matching to the VALIDATOR + LINKER for the cross-module sig fails
(type-subtyping.45/46/48/50: UnknownImport / SignatureMismatch on
structurally-equal-but-distinct-index func types across `register M`):
- The canonical-id algorithm lives in type_info.zig (`materialiseGcTypes`)
  but the validator + linker run pre-instantiate / cross-instance — they
  need a canonical-id computed from the DECODED `sections.Types` (validator)
  / from each instance's types (linker `sigEqual`). Likely: hoist the
  fold helpers + a `computeCanonicalIds(types)` into a shared spot
  (type_info or a parse-side helper) callable from both.
- Linker `sigEqual` (src/zwasm/linker.zig ~410): compare func param/
  result types by canonical id, not `ValType.eql` raw index.
- **HIGH BLAST RADIUS** if touching validator `gcConcreteReaches`
  (ADR-0124 / cyc122 parse-coupling — gc invalid regressed 55→40 once).
  Prefer the LINKER-only change first (lower risk, fixes the cross-module
  imports) + measure; validator-side canonical only if needed.
- Then **Phase-10b** (iso-recursive coinductive validator → 6 within-
  module type-subtyping fails) + ref_test_eq (extern↔any tag).
VERIFY FULL test-spec ALL proposals + assert_invalid (gc invalid 57) +
exit 0 + 0 panics. No regression to 344/90/57/393/34.

## Larger §10 work (later bundles)

- **funcrefs** return 32/39 — 1 externref-elem (runner externref-arg) +
  `resolveFuncrefGlobals` (off spec-corpus path). **10.P close gate** =
  user touchpoint by construction.

## Spec runner observable (cycle-164, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=344/407 trap=90/100 invalid=57/60 malformed=1/1 skip=20  ← 10.G c168
[multi-memory       ] return=393/407 trap=238/238  ← cyc141 rt.datas fix
```

> Use `--fail-detail` (reliable per-assert), NOT the per-manifest
> breakdown (over-counts gc). Real gc residuals: i31(4) + type-sub(5) +
> ref_test(2).

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
