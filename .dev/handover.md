# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — autonomous CORRECTNESS substantially COMPLETE**
  (Phase 9 = DONE 2026-05-24). All 4 proposals verified green except deep/deferred
  residuals (see Active bundle + §10 map).
- **HEAD**: `05266c03` (cyc235, docs-only debt-sweep). Session landed: cyc232
  cross-module `return_call` (call-and-return via ADR-0066 thunk; cohort-asymmetry
  → D-210); cyc233 EH×TC `return_call_in_try_table` (both ubuntu-verified);
  cyc234-235 Phase-10 survey + stale-debt correction (D-195 discharged, ADRs
  0115/0116/0123/0126 all Accepted, function-references + gc corpora GREEN).
- **10.P: 16 PASS / 8 SKIP / 0 FAIL → close-eligible.**
- **nix**: dev shell active (zig 0.16.0 / wabt / wasmtime; `wat2wasm
  --enable-tail-call --enable-exceptions`).

## Step 0.7 (next resume)

- cyc235 (`05266c03`) is docs-only (debt-sweep + lesson) → **no ubuntu kick**
  (non-code-gap). Last ubuntu-green code = `3933c9a7` (EH×TC) via caf7305b
  `OK (HEAD=caf7305b)`. No pending gate, no revert.

## Active bundle

- **Bundle-ID**: D-202-xmodule-finality
- **Cycles-remaining**: ~2-3 (deep GC type-system + linker; start fresh-context)
- **Continuity-memo**: `.30/.48/.50` instantiate `SignatureMismatch` comes from
  **`src/zwasm/linker.zig:434-458`** (C-API Linker func-sig compare, EXACT typeidx)
  — NOT `instantiate.zig:1654` (cyc192 `6a77cb19` fixed THAT path with
  `validator.funcTypeImportCompatible`, but the spec runner's cross-module
  linking routes through the C-API Linker, which still does exact compare). So
  cyc192's "SignatureMismatch 3→0" claim was path-incomplete. Fix = mirror
  funcTypeImportCompatible (contravariant params / covariant results, subtype)
  in linker.zig using exporter types reachable via `source_rt`
  (`Runtime.module_types` + `gc_type_infos.canonical_ids`). **Signal question
  (resolve FIRST)**: is the `.35/.36/.42/.52/.54` `assert_unlinkable` direction
  RUN+counted or skip-impl? (debt says "cyc193 implements assert_unlinkable to
  verify+count" — may still be skip → no RED until counted.) The gc gate is
  already GREEN (fails are only `.17`), so first establish the observable signal
  (a 2-module link test, or assert_unlinkable counting) before the fix.
- **Exit-condition**: `.30/.48/.50` cross-module subtype imports link (SignatureMismatch
  gone) verified by a test; if assert_unlinkable is counted, `.35` correctly
  rejected. Both arches, ubuntu-verified.

## Active task — D-202 cross-module type-identity (finality) check  **NEXT**

**cyc234-235 CORRECTION — the debt ledger is STALE and mis-routed the loop 3×
this session.** Ground-truth verification (ADR Status + live corpus, NOT debt
prose):
- ADR-0115 / 0116 / **0123 / 0126 are all ACCEPTED** (0123 "user-delegated
  autonomous flip" 2026-05-28). There is NO pending user ADR flip. Debt rows
  D-195 / D-198 saying "gated on ADR-XXXX Accept" are STALE.
- **function-references corpus GREEN** (ubuntu `return 39/0, trap 4/0,
  invalid 18/0, skip 1`) — **D-195 is DISCHARGED** (typed-funcref ValType
  `0x63/0x64` parser landed, `zir.zig:191`). Debt row stale.
- **GC corpus** GREEN except: `.17` (deferred multi-mechanism rabbit hole) +
  the **D-202 cross-module negatives** (`gc/type-subtyping.30/.48/.50`
  instantiate `SignatureMismatch`, `.35/.36/.42/.52/.54` assert_unlinkable
  wrongly-link).
- Lesson to write: *verify ADR Status + live corpus before trusting a debt
  row's "blocked-by ADR flip" framing* — three candidate chunks this session
  (D-195, the GC ADRs, the gc per-op "migration") were stale/misread.

So Phase 10 is NOT at a bucket-3 user-touchpoint — **D-202 is genuine open
AUTONOMOUS correctness work** (ADRs accepted; impl-only).

Resume Step 1b routes to the Active bundle above for the next step + discharge
D-195 (stale) / reconcile D-198 alongside. NOTE smell: `runner.zig` 1168 lines
(soft WARN) — future test sibling extraction.
**Formal Phase 10 close** (→ Phase 11) is a separate high-value user decision
(close-eligible, 0 FAIL); re-armable at any user signal. NOT a blocker on D-202.

## §10 close map + open

10.P close-eligible (0 FAIL). realworld/p10 matrix 45/55 (0 FAIL, 10 WASI-skip).
10.TC row `[ ]` (emit + spec + realworld clang_musttail + cross-module + EH×TC
all DONE; sole residual = `wasm_of_ocaml` triple-crown capstone, deferred to GC+EH
+toolchain — flip 10.TC `[x]` then). 10.E (EH) + 10.G (GC) are the large open
Phase-10 areas (GC has ADR-gated residuals D-195/D-198/D-202; D-179 wabt bake). gc
.17 funcref-RTT (D-198) deep defer; funcrefs 34/39 (5 RTT-gated); 10 SKIP-WASI →
Phase 11. D-197 (validate-error surfacing); D-209 (>4GiB memory64 offset, payload
u32); D-210 (cross-module proper-tail-call defer — arm64 prologue cohort-save).

## Key refs

- ADR-0066 (cross-module bridge thunk; cohort save/restore); ADR-0112 + Amendment
  2026-05-30 (cross-module tail-call = call-and-return); ADR-0111 (memory64);
  ADR-0114 (EH). `abi_callee_saved_pinning.md` (pinned cohort discipline).
- Lessons: `2026-05-30-{cross-module-tail-call-cohort-asymmetry,
  jit-funcref-tail-call-codegen-recipe, clang-wasm-realworld-toolchain-recipe}`.
  ROADMAP §10; `.dev/phase_log/phase10.md`.
