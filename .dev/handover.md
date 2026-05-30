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

## Active task — survey 10.E (EH) remaining work, then smallest open chunk  **NEXT**

10.TC is **implementation-complete**: emit (direct/indirect/ref/cross-module) +
spec corpus + realworld `clang_musttail` + EH×TC fixture all green. 10.TC stays
`[ ]` only because of the `wasm_of_ocaml` realworld fixture — a GC+EH+TC
**triple-crown capstone** (PROVENANCE `SKIP-P10-{GC,EH,TC}-GAP`) deferred until
10.G (GC) lands AND the wasm_of_ocaml/opam toolchain is provisioned in flake.nix
(not on PATH today). Do NOT flip 10.TC `[x]` until that capstone lands.
Next driving chunk = **Step 0 survey of 10.E (EH) remaining work** (ROADMAP 10.E
row: spec corpus 76 assertion, `eh_frequency_runner` impl, c_api tag accessors,
realworld `emscripten_eh` green, catch_ref/catch_all_ref exnref v0.2 per
ADR-0120) — find the smallest open EH item with the machinery already landed
(D-182/183/188 done), implement it. Fall back to 10.G non-ADR-gated items if 10.E
forward work is thin. NOTE smell: `runner.zig` 1168 lines (soft WARN) —
integration-test sibling extraction is a future refactor (phase-boundary audit).
**User touchpoint (held)**: Phase 10 close-eligible (10.P 0 FAIL); formal close
(→ Phase 11) is a high-value user decision, re-armable at any user signal.

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
