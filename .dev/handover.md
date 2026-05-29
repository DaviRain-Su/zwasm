# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 137 (`b13d4158`) — array typed-ref narrowing (mirror
  of cyc136): array.new/new_fixed push concrete `(ref $t)`; array.get/
  set/fill accept concrete via subtypeCtx. **ValidateFailed 41→38, trap
  4→6**. No regression; all unit tests green. gc return flat 49 — the
  unblocked struct/array fixtures hit an INSTANTIATE wall: struct.7 +
  array global fixtures init globals with `struct.new`/`array.new` CONST
  EXPRS, which evalConstExprValue defers (only ref.i31 handled, cyc130).
- cyc136 struct narrowing (`478cf035`); cyc135 GC-type threading (return
  48→49); cyc134 abstract-head lattice (33→48); cyc130-133 i31/element.
- Runner EXECUTES via interp; gc_heap + inst.gc_type_infos materialised
  at instantiate (instantiate.zig:859-880, BEFORE the globals loop ~1262).
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

## Active task — cycle 138: struct.new/array.new const-expr instantiation — **NEXT**

CONFIRMED return-unblocker: struct.7 (+ array global fixtures) init
globals `(ref $t)` with `struct.new`/`array.new`/`struct.new_default`
CONST EXPRS (e.g. struct.7 global0 = `f32.const×3; struct.new 0; end`).
`evalConstExprValue` (instantiate.zig ~694) handles only single consts +
ref.i31 → UnsupportedConstExpr → instantiate FAIL. Add struct.new/
struct.new_default/array.new[_default]/array.new_fixed to the global-init
eval: at the globals loop (~1262), rt.gc_heap + inst.gc_type_infos are
already materialised (~859-880), so reuse `feature/gc` allocate + the
struct_ops field-write logic to build the GcRef Value from the leading
const operands. Needs a context-aware evaluator (heap+type_infos), NOT
the bare evalConstExprValue. Red: struct.7 instantiates + its 7 returns
(new/get_*/set_get_*) pass. Observable: gc return ↑↑ (struct.7 ~7 +
array fixtures); no regression to 49 return / 6 trap / 57 invalid.

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
[gc                 ] return=407(pass=49 fail=334) trap=100(pass=6 fail=94) invalid=60(pass=57 fail=3) malformed=1(pass) ParseFailed=0 ValidateFailed=38  ← 10.G (cyc137; array narrowing, ValidateFailed 41→38, trap 4→6)
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
