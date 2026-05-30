# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `7131d711` (cyc232). **cyc232 = D-206 step 2 LANDED** — cross-module
  `return_call $import` JIT-compiles. Lowered to **call-and-return** through the
  ADR-0066 bridge thunk + epilogue + RET (= the emit shape of `call $import` then
  the function epilogue), NOT the frame-consuming BR/JMP of ADR-0112 D4.
- **Why call-and-return**: arm64 MOV-installs the pinned cohort (X19 + X24-X28)
  from the rt and never stack-saves it, so a frame-consuming cross-module
  tail-jump corrupts a same-module grand-caller's cohort (x86_64's per-frame R15
  save is safe). The thunk's call-and-return preserves the cohort on both arches.
  Filed: ADR-0112 Amendment 2026-05-30, lesson
  `cross-module-tail-call-cohort-asymmetry`, debt D-210 (proper-tail-call defer).
- **10.P: 16 PASS / 8 SKIP / 0 FAIL → close-eligible.**
- **nix**: installed + the dev shell is active (zig 0.16.0 / wabt / wasmtime /
  wasm-tools all via nix store; `wat2wasm --enable-tail-call` used to mint the
  cross-module test bytes).

## Step 0.7 (next resume — DO FIRST)

- cyc232 (`7131d711`) is a CODE change (cross-module return_call emit) → ubuntu
  kicked this turn (scope = JIT runtime). Next resume: `tail -3 /tmp/ubuntu.log`,
  expect `OK (HEAD=7131d711)`. **x86_64 RUNTIME execution** of the cross-module
  return_call (the 42 + nested cohort-99 harness tests) is verified there — Mac
  only exercises arm64; x86_64 was cross-compile-checked, not run.
- On ubuntu FAIL: revert `7131d711`; last green code = cyc230 `be9fb534`.

## Active bundle

- **Bundle-ID**: D-206-cross-module-TC
- **Cycles-remaining**: ~0-1 (exit-condition met on Mac arm64; ubuntu pending)
- **Continuity-memo**: cross-module return_call = call-and-return via ADR-0066
  thunk (cohort preserved); proper-tail-call (frame-consuming) deferred to D-210.
- **Exit-condition**: A.test `return_call $get` JIT-executes → 42 — DONE Mac
  arm64 (3 harness tests incl. nested cohort-99 preventive guard) + **ubuntu
  green** → then CLOSE (`check_bundle_active.sh --close`).

## Active task — D-206 bundle close (pending ubuntu)  **NEXT**

Next resume: confirm ubuntu green for `7131d711` (Step 0.7), then **close the
D-206-cross-module-TC bundle** (handover rewrite + chore commit). Then resume
Phase-10 autonomous work: the **10.TC spec corpus** (tail-call/test/core 95 wast
— the ROADMAP 10.TC `[ ]` row impl: bake corpus + run + realworld
clang_musttail/wasm_of_ocaml + EH×TC cross fixture) is the next driving chunk.
**User touchpoint (held)**: Phase 10 is close-eligible (10.P 0 FAIL); formal
close (→ Phase 11) is a high-value user decision, re-armable at any user signal.

## §10 close map + open

10.P close-eligible (0 FAIL). realworld/p10 matrix complete (8). 10.TC row `[ ]`
(spec corpus 95 wast + realworld + EH×TC fixture pending). gc .17 funcref-RTT
(D-198) deep defer; funcrefs 34/39 (5 RTT-gated); 10 SKIP-WASI → Phase 11. D-197
(validate-error surfacing); D-209 (>4GiB memory64 offset, payload u32); D-210
(cross-module proper-tail-call defer — arm64 prologue cohort-save).

## Key refs

- ADR-0066 (cross-module bridge thunk; cohort save/restore); ADR-0112 + Amendment
  2026-05-30 (cross-module tail-call = call-and-return); ADR-0111 (memory64);
  ADR-0114 (EH). `abi_callee_saved_pinning.md` (pinned cohort discipline).
- Lessons: `2026-05-30-{cross-module-tail-call-cohort-asymmetry,
  jit-funcref-tail-call-codegen-recipe, clang-wasm-realworld-toolchain-recipe}`.
  ROADMAP §10; `.dev/phase_log/phase10.md`.
