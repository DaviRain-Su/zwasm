# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc196 (`086c2991`) — **first clang-realworld fixture** (clang_smoke/
  loop_sum → JIT i32:55; edge_cases/p10). Proves the clang→wasm→zwasm pipeline.
  KEY FINDINGS (lesson `clang-wasm-realworld-toolchain-recipe`): clang recipe =
  `NIX_HARDENING_ENABLE="" PATH=<lld-20> clang --target=wasm32 -nostdlib
  -Wl,--no-entry -Wl,--export-all -O2`. Realworld-clang is HIGHER-cost / LOWER-
  marginal-value than assumed: (a) JIT can't run `return_call` (D-205, tail-call
  interp-only) → clang_musttail blocked; (b) `runI32Export` doesn't instantiate
  (clang shadow-stack -O0 traps) + no-arg funcs constant-fold → only trivial
  clang fixtures JIT-verify; (c) realworld-run fully instantiates but no result-
  check. Non-trivial clang fixtures need harness work.
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
- Mac+ubuntu green through cyc190 (`OK` exit 0). 10.G-gc + 10.H-multimem
  CLOSED cyc188. Cross-module sharing substrate: D-199 memory + D-201 table/func.

## Active task — cycle 197: reassess Phase-10-close path (realworld ROI changed) — **NEXT**

cyc196 materially changed the realworld assumption: result-checking NON-trivial
clang fixtures needs harness work (full-instantiation + invoke-with-result) AND
hits JIT feature gaps (D-205 tail-call), while the spec corpus ALREADY covers
the features (all 5 proposals green via interp). So realworld-clang is high-cost
/ low-marginal-value. Before sinking cycles into a fixture harness, **map what
Phase 10 close ACTUALLY requires** + pick the highest-ROI concrete chunk.
**cyc197 (read ROADMAP §10 + the 10.P close criteria)**: (1) Read ROADMAP §10
row 10.P + `scripts/check_phase10_close_invariants.sh` (if it exists) — are
realworld/p10 fixtures a HARD close-criterion, or is the green spec corpus
sufficient feature coverage? (2) Enumerate the genuine remaining Phase-10-close
work: 10.P invariants (the 23-item script), the deep gc edges (D-198 .17 /
D-202 finality+distinct-layout), JIT feature gaps (D-205 tail-call). (3) PICK
the highest-value concrete chunk: likely either the 10.P close-invariants script
(structural, advances the formal close) OR JIT tail-call (D-205, closes the
10.TC JIT half + unblocks clang_musttail) — choose by ROI, then execute.
**Bar**: a concrete commit (10.P invariant check, a debt/ROADMAP coherence
update, or the start of a chosen impl); no regression; test-all stays GREEN.

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
