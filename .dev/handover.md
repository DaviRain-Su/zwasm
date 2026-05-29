# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 132 (`8dc4e1af`) — thread real element-segment count
  into frontendValidate's validator call (was `elem_count=0` → `table.init`/
  `elem.drop` elemidx check rejected ALL such modules). Generic fix.
  **gc ValidateFailed 49→48** — i31.1 now COMPILES (its table.init
  validated). No regression. i31.1 returns still fail at EXECUTION
  (table-init must populate the i31ref table from element i31 slots).
- cyc131 (`5ed44656`) decode i31ref element segments (advanced i31.1
  past preDecode); cyc130 (`dc9d539a`) ref.i31 const-expr eval → **gc
  return 2→18, trap 0→2** (first big jump); cyc126-129 parse/validate.
- Runner EXECUTES via interp; GC handlers (i31/struct/array) +
  table.get/grow/fill/copy/init (generic) registered at api/instance.zig.
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

## Active task — cycle 133: i31ref table-init execution → i31.1 returns — **NEXT**

i31.1 now COMPILES; its assert_returns (size/get/grow/fill/copy/init on
the i31ref table) fail at EXECUTION because the ACTIVE element segment
isn't applied to the i31ref table at instantiation (table-init for
non-funcref). cyc131 stored the element's i31-encoded values in
`ElementSegment.funcidxs`; table-init must, for non-func-family
elem_type, write those slots into the table as anyref Values (i31
GcRef) instead of resolving funcidxs. Find the active-element →
table application code at instantiate (grep `funcidxs` consumers /
table population); dispatch on `elem_type`: func-family → funcref
(current), else → the encoded ref value directly. Table ops
(get/grow/fill/copy/init) are generic (registered) so should then work.
Confirm by instrumentation if a fixture still fails. Observable: gc
return ↑ (i31.1 ~14 asserts); no regression to 18 return / 2 trap / 57
invalid. Then i31.3/5/6 (likely same path) + struct/array exec.

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
[gc                 ] return=407(pass=18 fail=365) trap=100(pass=2 fail=98) invalid=60(pass=57 fail=3) malformed=1(pass) ParseFailed=0 ValidateFailed=48  ← 10.G (cyc132; i31.1 compiles, needs table-init exec)
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
