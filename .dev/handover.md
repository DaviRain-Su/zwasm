# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `ef34724c` (cyc198, 10.TC-JIT IT-2). **Direct `return_call` now
  JIT-executes end-to-end** via `runI32Export` (path (b) in progress). Root
  blocker was the liveness pass (`stackEffect-missing`): `return_call*` weren't
  classified as terminators, so `compileWasm` aborted before the already-wired
  arm64 emit ran. Fix: added them to the return/unreachable/throw drain branch
  in `src/ir/analysis/liveness.zig` (ADR-0113 §A). Mac test-all GREEN, lint clean.
  Phase 10 is formally CLOSE-ELIGIBLE (`check_phase10_close_invariants.sh` =
  16 PASS / 8 SKIP / 0 FAIL; spec corpus feature-complete via interp) but the
  in-scope ROADMAP §10 JIT halves (10.TC/E/G) aren't done — (b) completes them
  rather than deferring to Phase 11 via a §18 ADR (the path user paused on cyc197).
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
- **Cycles-remaining**: ~2 (IT-3 indirect+ref e2e → IT-4 clang_musttail / cross-module)
- **Continuity-memo**: liveness terminator-class for `return_call*` landed cyc198
  (`ef34724c`); direct `return_call` JIT-green via `runI32Export`. arm64 emit
  for direct (`emitDirectReturnCall`) + indirect (`emitIndirectReturnCall`,
  table-0/≤2-results) already wired (`emit.zig` dispatch). Remaining: e2e-verify
  `return_call_indirect` (liveness+emit both wired now — likely already works,
  needs a runI32Export test w/ table+elem); implement `return_call_ref` (still a
  one-line `UnsupportedOp` stub in `ops/wasm_3_0/return_call_ref.zig`); then
  clang_musttail realworld JIT-result-check + cross-module (`cross_module_tail_call.zig`,
  ADR-0112 D4 / 10.TC-3f). Interp trampoline already done (D-187).
- **Exit-condition**: all three `return_call*` variants JIT-execute via
  `runI32Export` + `clang_musttail` realworld fixture JIT-result-checked → D-205
  fully dischargeable; test-all GREEN, 0 panics.

## Active task — 10.TC-JIT IT-3  **NEXT**

Add a `runI32Export` test exercising `return_call_indirect` end-to-end (module
with a table + elem segment; exported `() -> i32` does `return_call_indirect`
through table[0]). liveness + emit are both wired now, so expect green or a
narrowly-localized emit gap. Then tackle the `return_call_ref` stub
(`ops/wasm_3_0/return_call_ref.zig` — funcref null-check + tail-jump, mirror
`call_ref` + the op_tail_call teardown/BR dance). Lighter queued: refresh stale
10.P SKIP rationales (I14/I21 reference resolved D-192/D-179).

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
