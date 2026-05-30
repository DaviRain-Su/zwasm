# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — now CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `9d493959` (cyc214). **D-209 FIXED**: realworld memory64 memarg-offset
  gap — clang `--target=wasm64`/lld emit the memarg `offset` as a width-padded
  (9-byte) LEB128, valid for a u64 (memory64) offset but the validator + lowerer
  decoded it at u32 width → `Error.Overlong`. Fix: validator `skipMemargOffset`
  (u64 width for memory64, keyed on `memory0_idx_type`); lowerer `readMemargOffset`
  (decode u64, range-check ≤ u32 for the payload slot) at both scalar + SIMD-lane
  sites. New realworld fixture `clang_wasm64/wasm64_load_store` (`(memory i64 2)` +
  i64-addressed store/load → 42) is a committed .wasm (runs without clang). Residual
  (> 4 GiB offset, payload-u32) → D-209 blocked-by. clang_musttail still 15 (no regression).
- **D-208 VERIFIED green on ubuntu** this cycle (Step 0.7: `OK (HEAD=733a0a98)`) — the
  x86_64 funcref-null-trap fix (usesRuntimePtr) holds. funcref-call + tail-call JIT
  matrix complete + verified both arches.
- **10.P close-invariants: 16 PASS / 8 SKIP / 0 FAIL** (`check_phase10_close_invariants.sh`
  → "close-eligible"). D-208 was the only FAIL. The 8 SKIPs are deferred-to-close-cycle
  (I3 cross fixtures unpopulated; I5/I11/I14/I16/I20/I23 deferred; I21 realworld tool-gated).
- **Step 0.7 on resume**: cyc214 is a CODE change (validate+lower) → ubuntu kicked on
  `9d493959`. VERIFY (`tail -3 /tmp/ubuntu.log`): the clang_wasm64 fixture + memory64
  corpus pass on x86_64. FAIL ⟹ revert pair (the offset-width change is the suspect).

## Active task — I3: populate test/edge_cases/p10/cross/ (cross-feature fixtures)  **NEXT**

Phase-10-close-prep, autonomous. The `test/edge_cases/p10/cross/` dir is empty (10.P I3
SKIP). Add cross-feature boundary fixtures that stress two Wasm-3.0 proposals interacting
(e.g. `call_ref` to a memory64 function; a `return_call` whose callee does a memory64
load; an EH handler that does a `call_ref`). Mirror the edge-runner `.wat`/`.wasm`/`.expect`
convention (runs via `runI32Export` JIT; `test/edge_cases/runner.zig`). Smallest red: one
fixture combining tail-call + memory64, run → expected i32. These can surface interaction
bugs the way clang_wasm64 surfaced D-209. Deferred: D-206 cross-module TC (multi-module
JIT harness — actionable but harness-build first); 10.G GC JIT (extreme).

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
