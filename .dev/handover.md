# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `bc47d75e` + this bundle-close chore (cyc232 close). **D-206
  cross-module `return_call` LANDED + bundle D-206-cross-module-TC CLOSED.**
  Code = `7131d711` (lowered to call-and-return through the ADR-0066 bridge
  thunk + epilogue + RET, NOT the frame-consuming BR/JMP of ADR-0112 D4).
  **ubuntu x86_64 verified `OK (HEAD=bc47d75e)`** — both arches green.
- **Why call-and-return** (load-bearing, see lesson + D-210): arm64 MOV-installs
  the pinned cohort (X19 + X24-X28) from the rt and never stack-saves it, so a
  frame-consuming cross-module tail-jump corrupts a same-module grand-caller's
  cohort (x86_64's per-frame R15 save is safe). The thunk's call-and-return
  preserves the cohort on both arches. Proper-tail-call (frame-consuming)
  cross-module deferred to D-210 (needs arm64 prologue cohort-save).
- **10.P: 16 PASS / 8 SKIP / 0 FAIL → close-eligible.**
- **nix**: installed + dev shell active (zig 0.16.0 / wabt / wasmtime via nix
  store; `wat2wasm --enable-tail-call` mints cross-module test bytes).

## Step 0.7 (next resume)

- cyc232 code (`7131d711`) is ubuntu-verified `OK (HEAD=bc47d75e)` THIS cycle —
  no pending ubuntu gate. This bundle-close commit is docs-only → **no ubuntu
  kick** (non-code-gap). Last ubuntu-green code = `7131d711` (via bc47d75e).

## Active task — 10.TC spec corpus  **NEXT**

The tail-call JIT matrix is COMPLETE (direct / indirect / ref / cross-module, both
arches). Next driving chunk = the **ROADMAP 10.TC `[ ]` row impl**: bake the
`tail-call/test/core` spec corpus (95 wast) via `scripts/regen_spec_3_0_assert.sh`
(or the tail-call-specific baker), wire it into the wasm-3.0 assert runner, run +
green it; then realworld `clang_musttail` + `wasm_of_ocaml` fixtures + the EH×TC
cross fixture. Start with Step 0 survey of the existing spec-assert baker + how a
proposal corpus (memory64 / EH) was wired, then the first chunk = bake + smoke the
tail-call corpus.
**User touchpoint (held)**: Phase 10 is close-eligible (10.P 0 FAIL); formal close
(→ Phase 11) is a high-value user decision, re-armable at any user signal.

## §10 close map + open

10.P close-eligible (0 FAIL). realworld/p10 matrix complete (8). 10.TC row `[ ]`
(spec corpus 95 wast + realworld + EH×TC fixture pending — the active task). gc
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
