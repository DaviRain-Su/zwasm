# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `e1b1c7cc` (cyc219). **6 cross-feature fixtures** in `test/edge_cases/p10/cross/`:
  call_ref/return_call/EH × memory64, EH × call_ref, multivalue × call_ref, + cyc219
  `call_indirect_memory64`→42 (table-dispatch × memory64). The first 5 are ubuntu-verified
  (cyc218 `OK d30e00a0`); cyc219's is Mac-green, ubuntu pending. **Cross-fixture vein is now
  essentially exhausted** — these are coverage LOCKS (all pass); they don't find bugs the way
  the realworld clang_wasm64 fixture found D-209 (real wide-LEB output). Remaining clean
  combos hit GC-JIT / multi-memory-JIT gaps.
- **D-206 surveyed → re-scoped + DEFERRED** (cyc218). The bundle was opened on a mis-estimate:
  the survey found the CURRENT cross-module call dispatch is INTERP-routed
  (`host_dispatch_base[i]` → `api/cross_module.zig:thunk` → `interp_mvp.invoke`; the
  `zwasm/linker.zig` Linker/CallCtx path, ADR-0109). There is NO native JIT→JIT cross-module
  bridge today — ADR-0112 D4's inline-bridge would be the FIRST, per-arch + a JIT-to-JIT
  2-module harness. ≈4-6 cycle architectural effort; NOT close-required (interp covers
  cross-module tail-call; spec corpus green). Recorded in the D-206 debt row; bundle closed.
- **I14 deferred** (cyc217): wasm.h tagtype accessors depend on the unimplemented
  type-reflection C-API family (functype/externtype) → Phase 13, not standalone 10.E.
- D-208 (cyc213) + D-209 (cyc214) fixed + ubuntu-verified. **10.P: 16 PASS / 8 SKIP / 0 FAIL**
  → close-eligible. All remaining SKIPs are deferred-to-close-cycle (I5/I11/I16/I20/I23),
  tool-gated (I21), or Phase-13 (I14). No autonomous SKIP-flip remains.
- **Step 0.7 on resume**: cyc219 added 1 fixture (call_indirect_memory64) → ubuntu kicked on
  `e1b1c7cc`. VERIFY (`tail /tmp/ubuntu.log`): the 6 cross fixtures pass on x86_64
  (FAIL ⟹ a call_indirect×memory64 x86_64 bug; fixture-only, low-risk revert).

## Active task — SIMD × call_ref cross fixture (last distinct combo)  **NEXT**

One more genuinely-distinct cross combo: **SIMD (v128) × call_ref** — a `call_ref` to a
funcref returning a `v128`; the caller extracts a lane → i32. Exercises the v128-result
capture path through the funcref JIT emit (more complex marshal than i32; previously
untested via call_ref). Mirror cross/ convention (`runI32Export` JIT; `wasm-tools parse`).
Smallest red: the fixture, run → expected i32. **After this, the cross-fixture vein IS
exhausted** — the loop must then shift (see below).
**User touchpoint (held, escalating)**: the high-value autonomous close-prep is DONE
(D-208/D-209 JIT fixes, 6→7 cross fixtures, caching fix, I14/D-206 scope findings). Phase 10
is close-eligible (10.P 0 FAIL). After SIMD×call_ref, the ONLY remaining autonomous work is
DEEP + not-close-required (D-206 native cross-module bridge ≈4-6 cyc; 10.G GC JIT extreme,
ADR-0113 §C; D-198 funcref/GC-RTT rabbit hole). The formal Phase-10 close (→ Phase 11) is a
user project-direction decision and is the genuinely highest-value next step. A user check-in
on "close Phase 10 vs commit a multi-cycle session to D-206/GC-JIT" is high-value. NOT a stop
— loop continues (next: bite into D-206 OR the realworld-harness result-check improvement,
whichever the resume judges best); re-arm holds.

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
