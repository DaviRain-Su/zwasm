# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 125 (`2d88524d`) — **ACTIVATED** GC subtype validation
  (ADR-0124): parse `sub`(0x4F)/`sub final`(0x50) → `Types.supertypes` +
  `Types.finals`; `validator.validateTypeSection` (≤1 super, in-bounds,
  declared-earlier, not-final, structural) wired into
  `preDecodeSectionBodies`. gc invalid MAINTAINED at pass=55 (no cyc122
  regression to 40 — validation load-bearing); 4 type-subtyping-invalid
  now parse→validate-REJECT (semantic). No regression elsewhere. `0x4E
  rec` deferred → valid ts fixtures still ParseFail. test+lint green.
- cyc124 (`b8248387`) validation half (inert); cyc123 ADR-0124
  (`0afb643f`); cyc122 parse-coupling finding; cyc121 survey.
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
- **Cycles-remaining**: ~5 (rec-parse → GC reftype-shortforms/lattice →
  struct/array exec → RTT materialise → array-copy/i31)
- **Continuity-memo**: `0x4F`/`0x50` subtype parse+validate DONE (cyc125).
  Remaining shared gap: `0x4E rec` group (decodeTypes ~141) still hits
  `else => InvalidFunctype`; valid type-subtyping fixtures mix bare 0x50
  + rec so need rec parse. Substrate already landed (don't rebuild):
  `feature/gc/` heap+type_info+i31+collector, validator `dispatchPrefixFB`
  no-RTT cut (~1315), ADR-0115/0116/0121/0124. Full ordered plan + the 5
  invalid-accepted (struct.3/4, array.1/3/4 = field-access kind-check)
  in `lessons/2026-05-29-wasmgc-corpus-scope.md`. **VERIFY by DIRECT
  binary run** (zig-build stderr cache/lossy — D-197 + cache lesson).
- **Exit-condition**: gc corpus return pass ≥ 50/407 (first execution
  slice via struct/array) — refine as chunks land.

## Active task — cycle 126: parse `0x4E rec` group → unlock valid GC fixtures — **NEXT**

cyc125 activated bare 0x50/0x4F subtype parse+validate. The valid
type-subtyping fixtures (ts.0-62) still ParseFail because they wrap
typedefs in `0x4E rec` groups (verified: ts.3 type1 = `4e 01 50 01 00
...`). Many fixtures MIX bare 0x50 + rec in one module, so rec parse is
required to make ANY of them parse.
Chunk: `parse/sections.zig decodeTypes` — handle `0x4E vec(subtype)`:
a rec group of N expands to N CONSECUTIVE type indices (the current
`for (items, 0..)` 1:1 loop must be restructured — rec consumes one
outer step but yields N entries; pre-scan count or two-pass). Each
inner subtype reuses the 0x50/0x4F/bare reader already landed. Forward
refs WITHIN a rec group become valid (relax `validateTypeSection`'s
`s >= i` for same-rec-group indices — track rec-group spans).
Red: `decodeTypes` rec-of-2 test (2 indices, mutual ref) + a valid ts
fixture parse test. Observable (DIRECT binary, D-197): gc ParseFailed ↓↓
+ valid type-subtyping fixtures start reaching validate (return/invalid
pass ↑). Watch for NO invalid regression (rec invalid fixtures must
still reject).

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
