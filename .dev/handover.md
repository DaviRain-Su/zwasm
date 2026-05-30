# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `<cyc217 docs/script>`. **All 4 I3 cross fixtures VERIFIED green on ubuntu**
  (cyc216 Step 0.7: `OK (HEAD=bb2a3471)`) — first real x86_64 run, un-cached by the
  has_side_effects fix. call_ref/return_call/EH × memory64 + EH × call_ref all pass both arches.
- **I14 surveyed → correctly DEFERRED** (cyc217). The wasm.h tagtype accessors are NOT a
  standalone 10.E chunk: `wasm_tagtype_new(wasm_functype_t*)` + `wasm_tagtype_as_externtype`
  DEPEND on the type-reflection C-API family (functype/externtype) which is UNIMPLEMENTED
  (src/api/ has only runtime-object accessors: func/global/memory/extern/trap/vec; zero
  *type* accessors). Implementing tagtype in isolation is incoherent → Phase 13 c_api scope.
  Close-invariant I14 rationale corrected to say so.
- D-208 (cyc213) + D-209 (cyc214) fixed + ubuntu-verified. **10.P: 16 PASS / 8 SKIP / 0 FAIL**
  → close-eligible. Remaining SKIPs all deferred-to-close-cycle (I5/I11/I16/I20/I23), tool-gated
  (I21), or Phase-13 (I14). No autonomous SKIP-flip remains.
- **Step 0.7 on resume**: cyc217 is DOCS/SCRIPT-only (I14 rationale + handover) → no ubuntu
  kick; green holds at `bb2a3471`. The NEXT code chunk (D-206) kicks ubuntu.

## Active bundle

- **Bundle-ID**: D-206-cross-module-TC
- **Cycles-remaining**: ~3
- **Continuity-memo**: (1) a multi-module JIT test harness (link 2 modules + JIT-run an
  exported entry — no current `runI32Export`-style multi-module path); (2) cross-module
  `return_call` inline-bridge emit (ADR-0112 D4; ADR-0066 thunk NOT reused) — arm64 + x86_64.
  Current block: `op_tail_call.emitDirectReturnCall` rejects `return_call` to an import
  (`if ins.payload < num_imports → UnsupportedOp`).
- **Exit-condition**: a 2-module fixture where module A's exported `test` does
  `return_call $imported` (a func imported from module B), JIT-executed → expected i32, on
  both arches, ubuntu-verified.

## Active task — D-206 cross-module tail-call JIT: multi-module JIT test harness  **NEXT**

Bundle D-206-cross-module-TC, step 1. The substantive arc-completer (D-205 same-module
tail-call → D-208 funcref-null → D-206 cross-module). Step 0 survey: how `runI32Export`
links + JIT-runs a single module; what a 2-module variant needs (the cross-module bridge
resolver in `engine/codegen/shared/linker.zig` / `cross_module.zig`); whether a
`runI32Export`-style 2-module helper can be added to `src/engine/runner.zig`. Smallest red:
a 2-module test where A return_calls B's imported func → expected i32 (will RED on
`emitDirectReturnCall`'s import-reject). NOT close-required (interp covers it) but completes
the tail-call JIT matrix. Deferred: 10.G GC JIT (extreme); funcref 34/39 + GC residual
(D-198 RTT rabbit hole, deep defer).

## §10 close map

Spec-corpus rows (10.G/10.M/10.E/10.TC/10.R) mature; 10.P now close-eligible (0 FAIL).
- **realworld/p10**: clang_musttail DONE (cyc201) + clang_wasm64 DONE (cyc214, JIT
  result-checked). emscripten/dart/ocaml/hoot TOOL-GATED (no toolchain).
- **gc .17** funcref-RTT (D-198) — deep defer. **funcrefs** 34/39 — 5 gated.
- **10.P close = user touchpoint** (see Open questions).

## Spec runner observable (cyc190, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=349/407 trap=96/100 invalid=60/60 ✅ malformed=1/1 skip=20
[multi-memory       ] return=407/407 trap=244/244  ← cyc188 ALL-GREEN
```
> gc residual: return=1 + trap=4 = type-subtyping.30/.48/.50. Use `--fail-detail`.

## Open questions / blockers

- D-197: validate-error surfacing ad-hoc via cyc143 op-probe; permanent diag = D-197 tail.
- D-206: cross-module tail-call JIT (multi-module harness-gated). D-209: > 4 GiB memory64
  offset (payload u32) deferred.
- **User touchpoint (2026-05-30)**: **Phase 10 is NOW close-eligible (10.P 0 FAIL)** — the
  last close-blocker (D-208) + the realworld memory64 gap (D-209) are cleared. The funcref/
  tail-call JIT matrix + memory64 realworld are DONE both arches. A user check-in on
  **formally closing Phase 10 (→ Phase 11) vs continuing JIT-completeness** (D-206
  cross-module TC, 10.G GC JIT — both NOT close-required; interp covers the corpus) is
  high-value here. NOT a stop — loop continues autonomously on I3 (close-prep); re-arm holds.

## Key refs

- ADR-0111 (memory64 D4/D5); ADR-0114 (EH); ADR-0115/0116/0121 (GC); ADR-0112 (tail-call).
- `.dev/lessons/2026-05-30-jit-funcref-tail-call-codegen-recipe.md` (D-208) +
  `2026-05-30-clang-wasm-realworld-toolchain-recipe.md` (clang musttail + wasm64).
- ROADMAP §10; `.dev/phase_log/phase10.md`; `scripts/check_phase10_close_invariants.sh`.
