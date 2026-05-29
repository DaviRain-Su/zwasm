# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc184 (`4a3d2ad3`) — **implemented `assert_uninstantiable`**
  (D-200): regen emits the directive + .wasm; runner instantiates
  (expect-fail), partial writes to shared memory persist (D-199).
  **multi-memory return 402→404 (+2)** (linking3 `load→97`) **+ trap
  238→244 (+6)** (the 6 uninstantiable asserts), skip 56→50. No regression.
  Earlier: D-199 shared memory (cyc182 +6), gc bundle COMPLETE 62→349 ret
  / 96 trap / 57 inv (cyc174/177/178/179).
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

- **Bundle-ID**: 10.H-multimem-linking (multi-memory linking/import
  return-fails — the next observable §10 cluster after the gc corpus).
- **Cycles-remaining**: open; next = cyc181 multi-memory fail triage.
- **Continuity-memo**: gc bundle (10.G) delivered 62→349 ret / 96 trap /
  57 inv — substrate DONE (`feature/gc/` heap+type_info+i31+collector,
  ADR-0115/0116/0121/0124/0125/0126 iso-recursive canon). gc residual
  DEFERRED (D-198: .17 rabbit hole + cross-module sig). **VERIFY by DIRECT
  binary run**; M3 attributes every compile FAIL.
- **Exit-condition**: multi-memory return > 396 (reduce the 11-fail
  linking/imports cluster). gc return ≥ 90 was long EXCEEDED (349).

## Active task — cycle 185: linking0/1 failed-instance funcref survival — **NEXT**

Last 3 multi-memory fails (after cyc184's +2/+6): linking0 `call(7)→0`
(1) + linking1 `Mm.load` (2), both `InvokeFailed`. The assert_uninstantiable
module writes an `elem` funcref into a SHARED table (linking0: Mt's table[7]
= the failed module's `$f`), then traps. Per spec the funcref stays
callable — but our failed instance is torn down → the funcref dangles →
`call(7)` traps (uninitialized/dangling). cyc185:
1. Verify the mechanism: probe linking0's `call(7)` interp error (cyc180
   pattern) — uninitialized-element vs dangling-deref.
2. Fix: the failed (uninstantiable) instance whose funcs are referenced
   cross-module must be ZOMBIE-PARKED (kept alive), like cross-module
   func imports (ADR-0014). Check whether `cur_linker.instantiate` already
   parks failed instances (cyc174 `failBuiltInstance` parkAsZombie) — if
   the runner deinits it, stop doing so for referenced funcs.
HIGH-ish (cross-module lifetime). If too deep, file a debt row + defer;
the +2/+6 already landed. Verify no regression to gc 349/96/57, multi-mem
≥404, exit 0, 0 panics.

## Larger §10 work (later bundles)

- **funcrefs** return 32/39 — 1 externref-elem (runner externref-arg) +
  `resolveFuncrefGlobals` (off spec-corpus path). **10.P close gate** =
  user touchpoint by construction.

## Spec runner observable (cycle-164, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=349/407 trap=96/100 invalid=57/60 malformed=1/1 skip=20  ← 10.G c179 (typed call_indirect)
[multi-memory       ] return=404/407 trap=244/244  ← cyc184 assert_uninstantiable (+2 ret/+6 trap)
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
