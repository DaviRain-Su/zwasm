# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 130 (`dc9d539a`) — `evalConstExprValue` handles the
  `ref.i31` const expr (`i32.const N; ref.i31; end`) at instantiation.
  Last gap for core i31: handlers were already registered (ext_i31_ops),
  validate fixed cyc124-129, only global-init eval remained. **gc return
  pass 2→18 (+16), trap 0→2** — full i31 pipeline works end-to-end
  (i31.0 + i31.4). No regression. test+lint green. **First big gc
  return-pass jump.**
- cyc129 (`0a3826ac`) ref.i31 non-null result (i31.0 validates); cyc128
  (`d6042f29`) scanInitExpr GC const-expr; cyc127 D-197 split; cyc126 rec
  parse + finality (return 0→2, invalid 55→57); cyc124-125 subtype validate.
- Runner EXECUTES via interp (`Instance.invoke` → `dispatch.run`), NOT
  JIT. GC interp handlers (i31/struct/array) registered at api/instance.zig:883+.
- cyc120 (`5db875b0`): cross-module EH propagation + caller-frame catch
  → **EH corpus FULLY GREEN 34/34** (bundle 10.E CLOSED; D-192 PROVEN).
- **Bundle 10.E-eh-tail CLOSED** — exit (return ≥ 33/34) met at 34/34;
  delta cyc119 (`9d5a6212`, *TagInstance: 31→32) + cyc120 (32→34).
  This completes the full EH cross-module substrate (cyc110–120,
  ADR-0114): parser→validator→instantiate-binding→*TagInstance
  identity→cross-module propagation. D-192 EH clause PROVEN.
- Mac green cyc120. ubuntu: cyc120 HEAD green (`OK (HEAD=40d7f0d0)`);
  cyc121-123 docs-only (survey/finding/ADR-0124, no kick).

## Active bundle

- **Bundle-ID**: 10.G-wasmgc (WasmGC spec corpus — the largest
  remaining §10 gap; follows the CLOSED 10.E EH chain)
- **Cycles-remaining**: ~5 (validate-attribute+fix → struct/array exec →
  RTT materialise → array-copy/fill → i31 exec)
- **Continuity-memo**: type-section PARSE complete (cyc124-126). cyc127
  proved all 51 remaining gc failures are VALIDATE (ParseFailed=0,
  ValidateFailed=51) — NOT execution (cyc126 guess wrong). Validator
  GC-op handlers live in `validator.dispatchPrefixFB` (~1315). Histogram
  + valid/invalid caveat in `lessons/2026-05-29-gc-corpus-block-is-
  validate-not-parse.md`. Substrate landed (don't rebuild): `feature/gc/`
  heap+type_info+i31+collector, ADR-0115/0116/0121/0124. The 5
  invalid-accepted (struct.3/4, array.1/3/4) in
  `lessons/2026-05-29-wasmgc-corpus-scope.md`. **VERIFY by DIRECT binary
  run**; compile FAILs now name the axis (ParseFailed/ValidateFailed).
- **Exit-condition**: gc corpus return pass ≥ 50/407 (first execution
  slice via struct/array) — refine as chunks land.

## Active task — cycle 131: i31.1/3/5/6 (tables of i31ref) ValidateFailed — **NEXT**

Core i31 (i31.0/4) DONE — full pipeline works. i31.1/3/5/6 still
ValidateFailed=49 (no return gain). They're tables of i31ref / anyref
with i31 init + table ops (size/get/grow/fill/copy/init per manifest).
Likely gaps: (a) the `(ref i31)` ELEMENT-segment init expr eval (mirror
cyc130's evalConstExprValue ref.i31 — find the element-segment
evaluator; may be a SEPARATE path from evalConstExprValue), and/or (b) a
validator gap on table ops over i31ref tables, and/or (c) the `0x40`
active-table-with-initexpr form. Localize i31.1 (smallest table
fixture): re-add the bounded func-loop / preDecode probe (cyc127/129
pattern) → exact error → fix. After i31: struct/array EXECUTION
(handlers registered at api/instance.zig:886-887; needs struct.new heap
alloc via collector + TypeInfo materialise at instantiate — bigger).
Observable: gc return/validate pass ↑; no regression to 18 return / 2
trap / 57 invalid.

## Larger §10 work (later bundles)

- **Deferred funcrefs gaps** (post-EH): funcrefs return 32/39 — 1
  externref-elem (runner externref-arg parsing) + engine/cli_run
  `resolveFuncrefGlobals` (off spec-corpus path).
- **multi-memory** — return 387/407 (20 fails), trap 237/238 (1).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (cycle-120/121, verified by DIRECT binary run)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34/34 trap=2/2 invalid=7/7 exception=4/4  ✅ FULLY GREEN
[function-references] return=39(pass=32 fail=1) trap=4(pass) invalid=18(pass)
[gc                 ] return=407(pass=18 fail=365) trap=100(pass=2 fail=98) invalid=60(pass=57 fail=3) malformed=1(pass) ParseFailed=0 ValidateFailed=49  ← 10.G (cyc130; i31 pipeline E2E)
[multi-memory       ] return=407(pass=387 fail=20) trap=238(pass=237 fail=1)
```

## Open questions / blockers

- D-197 (now-relevant at 10.G): `Engine.compile`/`frontendValidate`
  collapse specific errors to ParseFailed/bool — surfacing the real
  validate/decode error would make the gc 384-fail debugging precise.
  Discharge candidate this bundle.
- D-192: EH clause PROVEN (EH 34/34). funcrefs clause proven cyc108.

## Key refs

- ADR-0114 (EH `*TagInstance`, IMPLEMENTED cyc110–120); ADR-0115/0116/
  0121 (GC heap + type-info); ADR-0120/0123.
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (full EH journey) + `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
