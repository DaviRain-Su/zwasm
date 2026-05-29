# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc167 (ADR cycle, no gc delta — gc 343 held) — **ADR-0126
  filed**: WasmGC structural type canonicalization + iso-recursive rec-
  group subtyping (the deep type-system tail; D-198). Phased 10a
  (canonicalization → test-canon + cross-module sig fails) → 10b (iso-
  recursive coinductive validator → 6 type-subtyping fails). §18-required
  ADR-first for the §4 type-model deviation. cyc166 table-init-expr
  (i31.3 → i31 clean, +3); cyc161 externref args (+58). **gc 62→343**.
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

## Active task — cycle 168: ADR-0126 Phase-10a structural canonicalization — **NEXT**

ADR-0126 filed (cyc167). Implement **Phase-10a** (canonicalization;
LOW-risk, ~150 LOC, the prerequisite half). Survey blueprint:
- Compute a **canonical type id** per defined type from its comptype
  structure (kind + fields/elems/params/results + storage/mutability +
  recursively the canonical ids of contained concrete refs, rec-group
  self-refs resolved positionally). Preferentially at type-section
  decode / `materialiseGcTypes` (closed-world, once); store as a
  parallel `canonical_id[]` (NOT an index remap — less invasive).
- Consult canonical ids in: `ValType.eql`/subtype concrete compare
  (validator), `concreteReaches`/`gcRefMatchesNonNull` (runtime RTT),
  Linker `sigEqual` (cross-module). Fixes ref_test test-canon + the 4
  cross-module sig fails (type-subtyping.45/46/48/50).
- **HIGH BLAST RADIUS** (type-section decode is load-bearing; ADR-0124
  cyc122 parse-coupling regressed gc invalid 55→40). VERIFY FULL test-
  spec ALL proposals + assert_invalid (`gc invalid` must stay 57) +
  exit 0 + 0 panics. Then Phase-10b (iso-recursive coinductive) next.
Remaining gc residuals: type-subtyping=5 + ref_test=2 (test-canon +
eq-on-externalized). No regression to 343/90/57/393/34.

## Larger §10 work (later bundles)

- **funcrefs** return 32/39 — 1 externref-elem (runner externref-arg) +
  `resolveFuncrefGlobals` (off spec-corpus path). **10.P close gate** =
  user touchpoint by construction.

## Spec runner observable (cycle-164, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=343/407 trap=90/100 invalid=57/60 malformed=1/1 skip=20  ← 10.G c166
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
