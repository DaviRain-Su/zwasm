# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc175 (root-cause re-scope, no src) — traced the gc
  type-subtyping residual (5 fails = 3 FAILsetup + 2 FAILval) end-to-end:
  it's the Runtime-types **`ref.test`-on-funcref** modules, NOT the
  Linking cross-module imports (those pass). The miss in cyc170-172: a
  funcref `ref.test` never resolves the func's type idx (`readObjInfo`
  reads the GC heap, funcrefs aren't heap objects). RE-SCOPED to 3 pieces
  (ADR-0126 cyc175 amend). cyc174 (`cbcd081b`): start-exec → multi-mem
  393→396. cyc168/169 = Phase-10a; **gc 62→345**.
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
- **Cycles-remaining**: open; next = the cyc176 3-piece landing (below).
- **Continuity-memo**: substrate DONE (don't rebuild): `feature/gc/`
  heap+type_info+i31+collector, struct_ops/array_ops registered, ADR-0115/
  0116/0121/0124/0125. **VERIFY by DIRECT binary run**; M3 attributes
  every compile FAIL (`grep "compile FAIL.*op=0x"`).
- **Exit-condition**: gc return ≥ 90 **EXCEEDED (345)**. Open target:
  maximise return toward the corpus ceiling (D-198 tail = cyc176).

## Active task — cycle 176: gc ref.test-on-funcref 3-piece coordinated landing — **NEXT**

On-bundle (10.G), HIGH blast radius. Full decomposition + traps in
ADR-0126 "Phase-10b RE-SCOPED" (cyc175). Land 3 pieces TOGETHER (none
observable alone; 2-without-3 silently regresses `.wast` module 378):
1. **Validator `gcCanonicalEqual`** — narrow OR-arm in `gcValTypeSubtype`
   concrete→concrete (line ~2885): `... or gcCanonicalEqual(a,e,types)`.
   Recursive structural equality on `sections.Types` (kind + finality +
   canonically-equal supertypes + comptype, refs recurse, depth-32
   coinductive cutoff). **Verified SAFE cyc175** (invalid 57; shifts 1
   FAILsetup→FAILval). The exact helper is in the ADR section + was in
   the cyc175 reverted diff (`git show` the revert's parent if needed).
2. **Funcref→RAW typeidx in `ref_test_ops.gcRefMatchesNonNull`** — when
   `gti.entries[ht].kind == .func`, resolve `Value.refAsFuncEntity(v)` and
   `concreteReaches(fe.<RAW typeidx>, ht)`. **Do NOT use
   `FuncEntity.typeidx`** (canonicalized via `funcTypeEql` → collapses
   bare funcs → wrong). Get the raw declared typeidx (investigate
   `runtime.func_typeidxs[fe.func_idx]` or add a raw field).
3. **Precise equivalence-class `canonical_ids`** in `materialiseGcTypes`
   (O(n²) pairwise canonicalEqual; cyc168's coarse fold conflates rec-
   group context). **Regression boundary = `.wast` module 378** (`$f1≢$f2`
   → `ref.test` must return 0). Verify 348/360→1 AND 378→0 same run.
VERIFY FULL test-spec ALL proposals + assert_invalid: gc invalid stays 57,
multi-mem ≥396, exit 0, 0 panics. Then **4th probe**: the 2 residual
FAILsetup (modules still not compiling after piece 1).

## Larger §10 work (later bundles)

- **funcrefs** return 32/39 — 1 externref-elem (runner externref-arg) +
  `resolveFuncrefGlobals` (off spec-corpus path). **10.P close gate** =
  user touchpoint by construction.

## Spec runner observable (cycle-164, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=345/407 trap=90/100 invalid=57/60 malformed=1/1 skip=20  ← 10.G c169
[multi-memory       ] return=396/407 trap=238/238  ← cyc174 start-exec (+3 start0)
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
