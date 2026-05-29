# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `9a060476` (cyc199, 10.TC-JIT IT-3). **Direct AND indirect `return_call`
  now JIT-execute end-to-end** via `runI32Export` (path (b) in progress). IT-2
  root-caused the blocker to the liveness pass (`stackEffect-missing` —
  `return_call*` weren't classified as terminators, aborting `compileWasm`
  before the already-wired arm64 emit); fix = terminator-class in
  `src/ir/analysis/liveness.zig` (ADR-0113 §A). IT-3 proved `return_call_indirect`
  e2e (table[0] worker). Mac test-all + ubuntu GREEN through IT-2; IT-3 Mac
  test-all GREEN. Phase 10 is formally CLOSE-ELIGIBLE (spec corpus
  interp-feature-complete) but the in-scope ROADMAP §10 JIT halves (10.TC/E/G)
  aren't done — (b) completes them rather than deferring to Phase 11 (path user
  paused on cyc197).
- cyc196 (`086c2991`) first clang-realworld fixture (clang_smoke; pipeline proven).
  Realworld-clang findings: JIT can't run `return_call` (D-205); runI32Export
  doesn't instantiate; → non-trivial clang fixtures need harness work.
- cyc195 non-null-local definite-assignment → **test-all GREEN** (gate restored,
  bundle 10.Y closed). cyc194 restored wast-runner compile. cyc190-193: gc
  global-init / import subtyping / assert_unlinkable. gc residual: .17 (D-198)
  + 5 unlinkable (D-202). All Mac+ubuntu green through cyc195.
- Earlier arc: cyc177 iso-recursive canonicalEqual; cyc147-148 ADR-0125
  packed; cyc146 ADR-0016 M3 self-attribution; cyc130-140 i31/struct/array.
- Runner EXECUTES via interp; gc_heap + gc_type_infos + rt.datas all
  materialised at instantiate. Arrays use 8-byte uniform slots
  (type_info.slot_size); data-seg elements are NATURAL width.
- EH corpus FULLY GREEN 34/34 (ADR-0114 substrate cyc110-120; lesson
  `eh-cross-module-tag-substrate-scope` has the journey).
- **Step 0.7 on resume**: last ubuntu kick = cyc196 `OK (HEAD=517cb01a)`. cyc197
  (`544d4440` I2 script + `9996d478` handover) is DOCS/SCRIPT-only — not built by
  test-all — so the 517cb01a→9996d478 gap is a non-code-gap; ubuntu green holds,
  NO re-kick / revert needed. 10.G-gc + 10.H-multimem CLOSED cyc188.

## Active bundle

- **Bundle-ID**: 10.TC-JIT (D-205 discharge)
- **Cycles-remaining**: ~2 (IT-4 clang_musttail recursion-with-args → IT-5 cross-module)
- **Continuity-memo**: direct + indirect `return_call` both JIT-green e2e via
  `runI32Export` (IT-2 `ef34724c` liveness terminator-class + IT-3 `9a060476`
  indirect test). `return_call_ref` is OUT of this bundle — it's blocked on
  `call_ref` JIT codegen (NO `call_ref.zig` per-op file exists; function-references
  is interp-only, JIT = 10.R scope); tracked in D-205. Remaining IN bundle:
  `clang_musttail` realworld fixture (direct `return_call` recursion-WITH-ARGS —
  the actual D-205 trigger) JIT-result-check, then cross-module
  (`cross_module_tail_call.zig`, ADR-0112 D4 / 10.TC-3f). Interp trampoline done (D-187).
- **Exit-condition**: `clang_musttail` realworld fixture JIT-result-checked
  (direct return_call recursion-with-args executes correctly) + cross-module
  tail-call lands → bundle close; test-all GREEN, 0 panics. (direct + indirect
  e2e already met.)

## Active task — 10.TC-JIT IT-4  **NEXT**

Wire the `clang_musttail` realworld fixture (`test/realworld/p10/clang_musttail/`)
to JIT-result-check: it's a clang `__attribute__((musttail))` → `return_call`
recursion-with-args module — the actual D-205 trigger. Survey the realworld/p10
harness + the fixture's shape; if `runI32Export`-style execution doesn't fit
(no-arg-export constraint), add the needed entry helper. First confirm a
direct `return_call` WITH non-empty args + self-recursion JIT-executes (the IT-2/3
tests had zero args) via a unit test, then the realworld fixture. Lighter queued:
refresh stale 10.P SKIP rationales (I14/I21 reference resolved D-192/D-179).

## §10 close map (after this bundle)

Spec-corpus rows (10.G/10.M/10.E/10.TC/10.R) are mature but ROADMAP-`[ ]`;
formal close needs realworld/p10 + 10.P. Residual after the bundle:
- **realworld/p10** (skeleton): clang_wasm64 + clang_musttail AUTONOMOUS
  (clang✓), emscripten/dart/ocaml/hoot TOOL-GATED — next major chunk.
- **gc .17** funcref-RTT (D-198 multi-mechanism rabbit hole) — deep defer.
- **funcrefs** 34/39 — 5 gated; **10.P close gate** = user touchpoint.

## Spec runner observable (cyc190, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=349/407 trap=96/100 invalid=60/60 ✅ malformed=1/1 skip=20  ← cyc190 invalid-axis closed
[multi-memory       ] return=407/407 trap=244/244  ← cyc188 ALL-GREEN (D-199/200/201 cross-module chain)
```
> gc residual: return=1 + trap=4 = type-subtyping.30/.48/.50 (the bundle).
> Use `--fail-detail` (reliable per-assert), NOT the per-manifest breakdown.

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
