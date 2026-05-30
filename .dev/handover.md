# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — autonomous CORRECTNESS substantially COMPLETE**
  (Phase 9 = DONE 2026-05-24).
- **HEAD**: `ad011ab1` (cyc242). This long session (cyc232-242) landed +
  ubuntu-verified: cyc232 cross-module `return_call` (call-and-return; cohort
  asymmetry → D-210); cyc233 EH×TC `return_call_in_try_table`; cyc234-235 stale-debt
  correction (ADRs 0115/0116/0123/0126 all Accepted, D-195 discharged, fn-references
  + gc corpora GREEN — avoided a FALSE bucket-3); cyc236 D-202 PHASE A (linker
  cross-module subtyping, `.30/.48/.50` link); cyc239 D-202 PHASE B-finality
  (assert_unlinkable 5→4); cyc241 ADR-0127 (D-202 PHASE C design).
- **10.P: 16 PASS / 8 SKIP / 0 FAIL → close-eligible.**
- **nix**: dev shell active (zig 0.16.0 / wabt / wasmtime).

## Step 0.7 (next resume)

- cyc239 PHASE B-finality (`a4bd9bbb`) ubuntu-verified `OK (HEAD=64b27118)` —
  assert_unlinkable 5→4 + no regression, both arches green. cyc240-242 are docs-only
  (scope refine + ADR-0127 + revision) → no ubuntu pending, no revert.

## Bucket-3 stop — user touchpoint required  **NEXT**

All autonomous prep walked; **loop stops without re-arm** (cyc243). The session
drove Phase 10's clean autonomous correctness to substantial completion; the
remaining HIGH-VALUE work structurally needs the user, and the autonomous remainder
is intricate-fresh-context or low-value (continuing = the spin anti-pattern).

**Gating user touchpoint(s)**:
- **Formal Phase 10 close → Phase 11** (close-eligible, 10.P 0 FAIL). The loop has
  driven the autonomous correctness as far as it cleanly goes.
- **ADR-0127 `Proposed → Accept`** (D-202 PHASE C — cross-module func import
  type-identity). After Accept the loop implements PHASE C in a fresh-context cycle.

**Autonomous prep walked (do NOT re-walk)**:
- D-202 PHASE A + B-finality landed + ubuntu-verified (`38bb0e0e`, `a4bd9bbb`);
  assert_unlinkable 5→4.
- D-202 PHASE C fully scoped: ADR-0127 (design + alternatives + no-regression) +
  cyc242 impl-survey. The impl genuinely needs a NEW `canonicalEqualCross`
  (two-`Types` recursion; `sections.canonicalEqual` is single-`Types`) AND
  **retaining the exporter's `sections.Types`** (currently `defer types_owned.deinit()`
  at `instantiate.zig:82` frees it) — a memory-lifetime change + intricate
  type-system recursion, regression-risky (must keep multi-mem 407 + EH 34 +
  `.30/.48/.50` green). The naive cross-module index/supertype-reach shortcut is the
  rejected ADR-0127 Alternative A (regresses). Recipe in D-202 debt + ADR-0127.
- Lower-value autonomous items: gc per-op-file migration (behavior-preserving
  refactor; two dispatch patterns to untangle); gc_stress / eh_frequency runner
  本実装 (perf scaffolding).

**To resume**: Accept ADR-0127 (→ PHASE C impl next cycle) OR decide the Phase 10
close OR just `/continue` — in a fresh context the loop implements PHASE C per
ADR-0127, else falls back to the low-value items.

## §10 close map + open

10.P close-eligible (0 FAIL). realworld/p10 matrix 45/55 (0 FAIL, 10 WASI-skip).
10.TC row `[ ]` (emit + spec + realworld clang_musttail + cross-module + EH×TC all
DONE; sole residual = `wasm_of_ocaml` triple-crown capstone, deferred to GC+EH
+toolchain). 10.E (EH) + 10.G (GC) green corpora; residuals: `.17` (deferred); D-202
PHASE C (ADR-0127); 10 SKIP-WASI → Phase 11. D-197 (validate-error surfacing);
D-209 (>4GiB memory64 offset); D-210 (cross-module proper-tail-call — arm64 prologue
cohort-save).

## Key refs

- ADR-0066 (cross-module bridge thunk; cohort save/restore); ADR-0112 + Amendment
  2026-05-30 (cross-module tail-call = call-and-return); ADR-0127 (cross-module func
  import type-identity, Proposed); `abi_callee_saved_pinning.md`.
- Lessons: `2026-05-30-{cross-module-tail-call-cohort-asymmetry,
  stale-debt-rows-misroute-the-loop, clang-wasm-realworld-toolchain-recipe}`.
  ROADMAP §10; `.dev/phase_log/phase10.md`; D-202 debt (PHASE C recipe).
