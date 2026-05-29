# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `5457997c` (cyc201, 10.TC-JIT IT-5). **10.TC-JIT bundle CLOSED** — JIT
  tail-call codegen done + proven: direct 0-arg (IT-2), indirect table[0] (IT-3),
  recursion-WITH-ARGS (IT-4), and a **real clang `__attribute__((musttail))`
  fixture JIT-result-checked → 15** (IT-5). Root fix was the liveness
  terminator-class (`src/ir/analysis/liveness.zig`, ADR-0113 §A, IT-2); emit was
  already wired. New realworld-p10 JIT result-check harness (`build.zig`
  `run_edge_realworld_p10`, in test-all). Mac test-all GREEN; ubuntu GREEN
  through IT-4. **D-205 clang_musttail concern discharged**; 10.TC residuals
  (cross-module TC, return_call_ref) → debt. Phase 10 CLOSE-ELIGIBLE (spec corpus
  interp-complete); path (b) continuing the §10 JIT halves.
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

## Active task — survey remaining 10.TC/E/G JIT halves  **NEXT**

10.TC-JIT bundle CLOSED cyc201 (exit-condition met @ `5457997c`: clang_musttail
JIT-result-checked → 15). Next: a **survey** chunk to scope the highest-value
next JIT work under path (b) "complete 10.TC/E/G JIT halves", reporting current
status of each: 10.TC cross-module tail-call (`cross_module_tail_call.zig`,
ADR-0112 D4 — needs a multi-module JIT test harness; debt D-206); 10.E EH JIT
codegen (substrate ADR-0114 built, interp 34/34 — what's the JIT-emit status?);
10.G GC JIT codegen. Output → `private/notes/p10-jit-halves-survey.md`; end with
a recommended next concrete chunk. Known 10.TC residuals are debt-rowed (D-206
cross-module; D-205-tail `return_call_ref` blocked-by `call_ref` JIT / 10.R).
Lighter queued: refresh stale 10.P SKIP rationales (I14/I21 reference resolved
D-192/D-179).

## §10 close map

Spec-corpus rows (10.G/10.M/10.E/10.TC/10.R) are mature but ROADMAP-`[ ]`;
formal close needs realworld/p10 + 10.P. Residual:
- **realworld/p10**: clang_musttail DONE (cyc201, JIT result-checked); clang_wasm64
  next-AUTONOMOUS (clang✓); emscripten/dart/ocaml/hoot TOOL-GATED.
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
