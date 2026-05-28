# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 108 (`e3a22ec2`) — `ref.func` in a global init expr
  now resolves at instantiate (evalConstExprValue had no 0xD2 arm; the
  global-init loop resolves against rt.func_entities). With cycle-107's
  `register M`, **ref_func.1 instantiates + runs its 8 asserts**:
  function-references **return pass 24 → 32**. D-192 funcrefs clause MET.
- Prior: 107 register M baked (`590578e1`); 106 scoping/pivot
  (`e0766509`); 105 element ref.func func-family + ParseFailed→0
  (`6e58b534`); 104 unreachable-poly (`8304714d`); 100-103 funcrefs
  parse chain.
- Mac test + lint green (cycle 108). ubuntu: cycle-107 HEAD green
  (`bb426c07`); cycle-108 kick backgrounded.

## Active bundle

- **Bundle-ID**: 10.E-xmodule-tags (EH cross-module tag imports per
  ADR-0114; D-192 register's funcrefs clause CLOSED cycle 108)
- **Cycles-remaining**: ~5
- **Continuity-memo**: D-192 register substrate PROVEN (funcrefs
  return 24→32 cyc100-108). EH clause = a MAJOR designed-but-unimpl
  substrate (ADR-0114) — full scope + the 5-step plan in
  `lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`.
  try_table.1 imports `test::e0` (TAG ×2) + `test::throw` (func) from
  try_table.0. Gaps: ImportKind has no `.tag` (parser rejects 0x04);
  tag exports filtered at decode (`sections.zig:606`); no
  `ImportBinding.tag` / Linker tag API; tag identity index-based
  (`exception.zig` tag_idx) not ADR-0114 `*TagInstance` → cross-module
  throw/catch can't match. Plan: parser(1)→instantiate(2)→TagInstance
  storage(3)→identity match(4)→JIT(5). Steps 1-2 are 0-corpus-delta;
  frame each cycle's observable as the STAGE move (parse→instantiate→
  match), not corpus count, until step 4.
- **Exit-condition**: exception-handling try_table corpus return pass
  ≥ 5/34 (currently 0/34) — i.e. cross-module throw/catch matches via
  `*TagInstance` for at least the simple-throw-catch cases.

## Active task — cycle 110: EH tag-import parser side (step 1 of ADR-0114 substrate)

**Step 0 done (cycle 109 survey)** — see the lesson. Step 1 (smallest
observable): extend `parse/sections.zig` `ImportKind` with `tag = 0x04`
+ `ImportPayload.tag_typeidx` + accept `0x04` in the import-kind switch
(line ~286), and un-filter tag exports (`sections.zig:606` — recognise
kind=4 export as a `.tag` ExportDesc variant instead of dropping). Red
test: decode an import section with a tag import (`0x04` kind) +
assert the ImportKind.tag entry; decode a tag export + assert it
appears. Observable: try_table.1 PARSES past the tag import (ParseFailed
→ instantiate-stage). NOTE: the ImportKind enum extension cascades into
every `switch (ImportKind)` (instantiate, linker) — those arms land in
step 2; step 1 may need stub arms to compile. Deviation watch: ADR-0114
is the design (Accepted); this is impl, not a §4 deviation.

## Larger §10 work (later bundles)

- **10.E EH spec corpus (Gate 1 / D-192)** — try_table.1.wasm imports
  `test::e0` tag + `test::throw` func from try_table.0.wasm; runner
  registry needs tag + func cross-module binding. Gate 2 (exnref byte
  `0x69` standalone + `ValType.exnref` pub-const) folds in here.
- **10.G WasmGC** — corpus baked (568) impl=0%; ZIR ops + heap +
  subtype lattice (10.G refines `valTypeIsSubtypeFree`'s pre-GC
  `(ref $concrete) <: func` assumption).
- **Deferred funcrefs gaps** (post-D-192-EH): engine/cli_run
  `resolveFuncrefGlobals` unwired (ref.func globals null in cli_run);
  externref-elem (runner externref invoke-arg parsing). Both real but
  off the spec-corpus path.
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-108)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass) exception=4(fail4)
[function-references] return=39(pass=32 fail=1) trap=4(pass=4) invalid=18(pass) ParseFailed=0  (return 0→7→12→24→32 cyc100-108; only externref-elem left)
[gc                 ] return=407(fail) trap=100(fail) invalid=60(pass=55 fail=5) malformed=1(pass)
[multi-memory       ] return=407(pass=371 fail=36) trap=238(pass=237 fail=1)
```

## Open questions / blockers

- ADR-0120 / ADR-0123: Accepted; impl autonomous. ADR-0123 D4
  (ref.func typed) landed cycle 102.
- D-192: register substrate PROVEN (funcrefs). EH clause = active
  bundle 10.E-xmodule-tags (ADR-0114 *TagInstance impl).
- D-186 (return_call_ref): discharge predicate met by ADR-0123 D4 +
  cycle-102 opRefFunc typed push.

## Key refs

- ADR-0120 (Accepted — EH payload), ADR-0123 (Accepted — typed-ref;
  D4 ref.func typed landed cycle 102).
- `.dev/lessons/2026-05-28-funcrefs-tail-error-classes.md` (gate
  inventory + cycle-101/102 re-probe maps).
- ROADMAP §10; `.dev/phase_log/phase10.md`.
