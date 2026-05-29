# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 127 (`e14380ec`) — **D-197 partial discharge**: split
  `Engine.CompileError` into `ParseFailed` vs `ValidateFailed`.
  Behavior-neutral (no pass-count change); the runner now shows the
  axis. **Revealed: gc ParseFailed=0, ValidateFailed=51** — GC
  type-section PARSE is COMPLETE; ALL 51 remaining gc failures are
  VALIDATE (cyc126's "execution-blocked" guess was wrong). Histogram +
  finding in new lesson. test+lint green; no regression.
- cyc126 (`7a44b8f4`) 0x4E rec parse + 0x50/0x4F finality fix (gc
  return 0→2, invalid 55→57); cyc125 (`2d88524d`) subtype validate;
  cyc124 validation half; cyc123 ADR-0124; cyc121 survey.
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

## Active task — cycle 128: attribute gc VALIDATE failures, fix dominant valid-fixture class — **NEXT**

cyc127 proved the 51 remaining gc failures are all VALIDATE (parse
complete). The validate-error histogram (whole corpus, MIXES valid-gaps
+ correct invalid-rejections — see lesson): StackTypeMismatch×51,
InvalidAlignment×37, StackUnderflow×28, InvalidFuncIndex×17,
ArityMismatch×16, NotImplemented×10 (=struct/array get_s/u packed,
deferred). i31.0/1/3/4/5/6 fail BEFORE the func loop (preDecode/
validateTypeSection/early-return), a distinct sub-class.
Chunk: FIRST attribute — for the ~16 gc VALID return fixtures, find
which validate error each hits (re-add the throwaway per-func probe OR
map by manifest assertion type). THEN fix the dominant valid-fixture
validate gap (likely a GC-op typing bug in `validator.dispatchPrefixFB`
~1315, e.g. struct.get/array.get result typing, or ref.cast narrowing).
Start with the i31 pre-func-loop sub-class (smallest, isolatable): pick
i31.0, trace which `return false` in preDecodeSectionBodies/
validateTypeSection fires. Observable: gc return/invalid pass ↑, no
regression to 2 return / 57 invalid.

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
[gc                 ] return=407(pass=2 fail=382) trap=100(fail) invalid=60(pass=57 fail=3) malformed=1(pass) ParseFailed=0 ValidateFailed=51  ← 10.G (cyc127)
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
