# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 136 (`478cf035`) — struct typed-ref narrowing
  (ADR-0116): struct.new pushes concrete `(ref $t)`; new
  `Validator.subtypeCtx` adds the GC concrete→abstract rule (struct/array
  ref <: eq/any/struct/array via module_types_kinds), routed through
  popExpect + expectFrameEndTypes + struct.get/set. **struct FAIL 5→2,
  ValidateFailed 44→41, trap 2→4**. No regression; all unit tests green.
  gc return flat 49 (struct RETURN asserts need exec verified next).
- cyc135 GC-type threading (return 48→49); cyc134 abstract-head lattice
  (33→48); cyc133 element→table init (18→33); cyc130-132 i31 exec.
- Runner EXECUTES via interp; struct substrate landed (struct_ops.zig
  struct.new/get/set + rt.gc_heap via setupGcHeap; handlers registered).
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

## Active task — cycle 137: struct RETURN execution + array narrowing — **NEXT**

cyc136 narrowed struct types → struct.5/7 compile + trap-asserts pass,
but RETURN asserts flat at 49. Verify struct EXECUTION end-to-end:
instrument a compiling struct fixture's assert_return — does struct.new
(heap alloc via rt.gc_heap) + struct.get return the right value, or
wrong/trap? (struct_ops.zig substrate landed; check resolveStructInfo /
TypeInfo materialise at instantiate — rt may lack the StructInfo the
handler needs). Fix → struct return passes. THEN apply the SAME
narrowing to array (array.new push concrete `(ref $t)` + array.get/set/
fill/len accept concrete via subtypeCtx — mirror cyc136; ~6 edits) →
array fixtures. Also queue: struct.0/10 + i31.3 (preDecode gaps).
Observable: gc return ↑ (struct/array); no regression to 49/4/57.

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
[gc                 ] return=407(pass=49 fail=334) trap=100(pass=4 fail=96) invalid=60(pass=57 fail=3) malformed=1(pass) ParseFailed=0 ValidateFailed=41  ← 10.G (cyc136; struct narrowing, struct FAIL 5→2, trap 2→4)
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
