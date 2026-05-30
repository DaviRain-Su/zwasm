# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `3933c9a7` (cyc233). **EH×TC integration fixture LANDED** —
  `return_call` inside `try_table` (ROADMAP `return_call_in_try_table`). Two
  `runI32Export` assertions: tail-callee throw ESCAPES the caller's `catch_all`
  (frame consumed → trap), non-throwing tail-call → 77. Mac arm64 green; correct
  by construction (static per-PC exception table + FP-chain walk skips the
  consumed frame), no emit change needed.
- **Prior (cyc232, `7131d711`)**: D-206 cross-module `return_call` via
  call-and-return through the ADR-0066 bridge thunk (NOT the frame-consuming
  BR/JMP of ADR-0112 D4 — arm64 MOV-installs the X19/X24-X28 cohort, so a tail
  -jump corrupts a same-module grand-caller; thunk preserves it). Bundle CLOSED;
  ubuntu-verified `OK (HEAD=bc47d75e)`. Proper-tail-call cross-module → D-210.
- **10.P: 16 PASS / 8 SKIP / 0 FAIL → close-eligible.**
- **nix**: installed + dev shell active (zig 0.16.0 / wabt / wasmtime via nix
  store; `wat2wasm --enable-tail-call --enable-exceptions` mints the test bytes).

## Step 0.7 (next resume — DO FIRST)

- cyc233 (`3933c9a7`) is a test that exercises the JIT runtime (return_call ×
  try_table) → ubuntu kicked this turn. Next resume: `tail -3 /tmp/ubuntu.log`,
  expect `OK (HEAD=3933c9a7)` — verifies the EH×TC interaction on x86_64 (Mac
  only ran arm64). On FAIL: revert `3933c9a7`; last ubuntu-green = `7131d711`
  (via bc47d75e).

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

Next driving chunk = **D-202**: implement cross-module structural type-identity
(finality + declared-supertype + canonical) comparison in
`instantiate.zig::checkImportTypeMatches` (`.cross_module` arm) +
`validator.zig::funcTypeImportCompatible`. The exporter types are reachable via
`source_rt` (`Runtime.module_types` + `gc_type_infos.canonical_ids`) but the
rec-group structure for cross-`Types` `canonicalEqual` is not threaded into the
`cross_module` binding. **FIRST verify the discrepancy**: D-198 cyc192
(`6a77cb19`) claimed `.30/.48/.50` SignatureMismatch 3→0, but the current ubuntu
log shows them FAILing again — confirm whether cyc192 regressed or the fix was
partial, via the spec runner per-module emit. Then thread exporter type info +
the structural compare (monotonic-safe: eql-first, subtype/identity-fallback).
Step 0 survey: `instantiate.zig::checkImportTypeMatches` + `validator.zig::funcTypeImportCompatible`
+ how `source_rt` exposes exporter `Types`. May be multi-cycle → open a bundle.
Discharge D-195 (stale) + reconcile D-198 in the same or next chunk.
NOTE smell: `runner.zig` 1168 lines (soft WARN) — future test sibling extraction.
**User touchpoint (HIGH-VALUE, held)**: Phase 10 is close-eligible (10.P 0 FAIL,
TC+EH done). The two highest-value next moves are USER-GATED: (1) formal Phase 10
close → Phase 11, (2) GC (10.G) ADR-0123 / ADR-0126 `Proposed → Accepted` flips
(D-195 typed-ref parser, D-198 iso-recursive subtype) which unblock the bulk of the
remaining GC corpus. Loop continues autonomously on c_api meanwhile; re-armable to
either user-gated path at any signal.

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
