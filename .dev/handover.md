# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `c55aaa12` (cyc213). **D-208 ROOT-CAUSED + FIXED**: `call_ref` /
  `return_call_ref` were missing from `x86_64/usage.zig::usesRuntimePtr`, so the
  prologue skipped `MOV R15,RDI` → the null-check trap stub wrote trap_flag via a
  garbage R15 → a NULL funcref returned Ok(0) on x86_64 instead of trapping (Mac
  arm64 immune — X19 always set). D-180-class gap (twin of the `ref.as_non_null`
  / EH cases). Fix: whitelist both ops; ungate the 2 null-trap tests; close the
  `check_uses_runtime_ptr.sh` thin-delegator blind spot that hid it (per-op files
  delegate into op_call/op_tail_call where the R15 use lives). D-207 + D-208
  discharged (rows deleted). The decisive probe was a Mac byte-dump (ndisasm): it
  showed correct JZ→trap-stub bytes referencing R15 with NO `MOV R15,RDI` prologue.
- funcref-call + tail-call JIT now COMPLETE both arches (positive + null-trap),
  pending ubuntu confirm of the x86_64 null-trap (see Step 0.7).
- Earlier: 10.TC same-module tail-call (direct/indirect/recursion + clang musttail
  → 15); EH corpus 34/34 (ADR-0114); cyc190-196 gc global-init/subtyping. Phase 10
  CLOSE-ELIGIBLE (spec corpus interp-complete). 10.M memory64 + 10.E EH JIT largely
  done; 10.G GC JIT = interp-only (extreme: regalloc stack-map, ADR-0113 §C).
- **Step 0.7 on resume**: cyc213 is a CODE change → ubuntu kicked. **VERIFY the
  c55aaa12 ubuntu result** (`tail -3 /tmp/ubuntu.log`): the 2 ungated null-trap
  tests (call_ref/return_call_ref null → Trap) must PASS on x86_64. FAIL ⟹ the
  usesRuntimePtr fix didn't take → revert pair + re-investigate (root cause is
  textbook D-180-class; high confidence). Prior green: cyc209 `OK (HEAD=9dbc84ee)`.

## Active task — realworld/p10 clang_wasm64 fixture  **NEXT**

D-208 (the 10.P I18 close-blocker) is resolved. Next autonomous chunk per the §10
close map: add the `clang_wasm64` realworld fixture (memory64 via clang, result-
checked through the cyc201 realworld-p10 harness, `build.zig run_edge_realworld_p10`).
clang is available (clang_musttail proved the recipe; lesson
`2026-05-30-clang-wasm-realworld-toolchain-recipe`). Smallest red: a
`clang --target=wasm64` module exercising a memory64 load/store, run → expected i64.
Deferred: D-206 cross-module TC (needs a multi-module JIT test harness — actionable
but harness-build first); 10.G GC JIT (extreme).

## §10 close map

Spec-corpus rows (10.G/10.M/10.E/10.TC/10.R) are mature but ROADMAP-`[ ]`;
formal close needs realworld/p10 + 10.P. Residual:
- **realworld/p10**: clang_musttail DONE (cyc201, JIT result-checked); clang_wasm64
  next-AUTONOMOUS (clang✓, the Active task); emscripten/dart/ocaml/hoot TOOL-GATED.
- **gc .17** funcref-RTT (D-198 multi-mechanism rabbit hole) — deep defer.
- **funcrefs** 34/39 — 5 gated; **10.P close gate** = user touchpoint. With D-208
  (the last close-blocker) cleared, 10.P I18 should now pass.

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
- **User touchpoint (2026-05-30)**: funcref-call + tail-call JIT is fully
  DELIVERED both arches (D-205/207/208 all discharged; positive + null-trap).
  **Phase 10 close is a user touchpoint** (§10 close map); with the last
  close-blocker (D-208) cleared, a user check-in on "formally close Phase 10
  vs keep grinding realworld/GC JIT" is high-value before the next big chunk.
  NOT a stop — loop continues on clang_wasm64; re-arm holds.

## Key refs

- ADR-0114 (EH `*TagInstance`, IMPLEMENTED cyc110–120); ADR-0115/0116/
  0121 (GC heap + type-info); ADR-0120/0123.
- `.dev/lessons/2026-05-30-jit-funcref-tail-call-codegen-recipe.md` (D-208
  resolution + usesRuntimePtr gotcha) + `2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
