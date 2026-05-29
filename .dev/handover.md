# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 124 (`b8248387`) — GC structural subtype **validation
  half** per ADR-0124 (validate-first to avoid the cyc122 parse-only
  regression): `validator.typeDefIsSubtype` + `gcHeapAbstractSubtype`
  lattice + `gcConcreteReaches` chain + `gcValTypeSubtype` +
  `gcFieldSubtype` (struct width+depth / array+func variance) + inert
  `Types.supertypes` field + unit tests. Behavior-neutral (gc unchanged,
  no 0x50 parse yet); test+lint green.
- cyc123 ADR-0124 (`0afb643f`); cyc122 parse-coupling finding; cyc121
  survey.
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
- **Cycles-remaining**: ~6 (rec-parse → lattice/invalid → struct/array
  exec → RTT materialise → array-copy/i31)
- **Continuity-memo**: gc = 87/88 ParseFailed; biggest = type-subtyping
  ×44, all need recursive type forms. The shared gap: `sections.zig`
  `decodeTypes` (~135-166) switches `0x60/0x5F/0x5E` then `else =>
  InvalidFunctype` — `0x4E rec` / `0x4F sub` / `0x50 sub final`
  unhandled. Substrate already landed (don't rebuild): `feature/gc/`
  heap+type_info+i31+collector, validator `dispatchPrefixFB` no-RTT cut
  (~1315), ADR-0115/0116/0121. Full ordered plan + the 5
  invalid-accepted (struct.3/4, array.1/3/4 = field-access kind-check)
  in `lessons/2026-05-29-wasmgc-corpus-scope.md`. **VERIFY by DIRECT
  binary run** (zig-build stderr cache/lossy — D-197 + cache lesson).
- **Exit-condition**: gc corpus return pass ≥ 50/407 (first execution
  slice via struct/array) — refine as chunks land.

## Active task — cycle 125: ACTIVATE GC subtype (parse 0x50/0x4F + wire) — **NEXT**

cyc124 landed the validate half (inert). cyc125 turns it on (commit
parse+wire TOGETHER — parse alone regresses, cyc122):
(a) `parse/sections.zig decodeTypes` (~135-166): handle `0x50` (sub
final) / `0x4F` (sub) — read `vec(typeidx)` supertypes into the present
`Types.supertypes` (now all `&.{}`); bare comptype → empty. Each subtype
its own index; **NO `0x4E rec` flattening** (hexdump: rec=4E sub=4F
sub-final=50). This is the reverted cyc122 diff, now SAFE.
(b) `validate/validator.zig`: type-section pass calling the landed
`typeDefIsSubtype(sub,sup,types)` — reject non-conformance + final-super
extension. Wire into `frontendValidate` (+ Engine.compile type-validate
point if separate). Red: 0x50 parse test + frontendValidate reject test.
Observable (DIRECT binary, D-197 stderr-lossy): gc ParseFailed ↓ AND
invalid ≥55 (target 60, no regression — validate now rejects bad fixtures).

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
[gc                 ] return=407(pass=0 fail=384) trap=100(fail) invalid=60(pass=55 fail=5) malformed=1(pass)  ← 10.G
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
