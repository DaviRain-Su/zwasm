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

## Active task — c_api EH type-reflection (wasm_tagtype_*)  **NEXT**

**10.TC + 10.E codegen + spec corpora are DONE this session.** 10.TC stays `[ ]`
only for `wasm_of_ocaml` (GC+EH+TC capstone, toolchain+GC-deferred). 10.E codegen
green (D-182/183/188 + EH×TC); try_table spec corpus = 2 text-format skips (legit
ADR). **10.E survey result (cyc233):**
- `eh_frequency_runner` = benchmark *skeleton* (`test/runners/eh_frequency_runner.zig`),
  perf scaffolding only — low signal, defer.
- realworld `emscripten_eh/` = PROVENANCE-only placeholder (emscripten EH
  toolchain not provisioned) — deferred like wasm_of_ocaml.
- **c_api tag accessors**: `wasm_tagtype_*` declared `include/wasm.h:252-296` but
  the WHOLE wasm-c-api **type-reflection** layer is unimplemented — `src/api`
  exports 49 runtime fns (engine/instance/func/global/memory/extern) but NO
  `wasm_functype_*` / `wasm_*type` type-objects. So "tag accessors" needs the
  type-object infra (valtype/functype/externtype) built first.

**cyc234 finding: Phase 10 autonomous CORRECTNESS is substantially COMPLETE.**
Surveyed + verified all 4 proposals: memory64 done (D-209 >4GiB deferred); TC done
(wasm_of_ocaml capstone deferred); EH done (c_api tags = v0.1.0 scope per ROADMAP
§1.2, NOT Phase 10; eh_frequency/emscripten = perf/toolchain deferred); **GC corpus
GREEN** — ubuntu `gc: return 349/1, trap 96/4, invalid 60/0, skip 12`; the only
fails are gc/type-subtyping `.17` (deferred multi-mechanism rabbit hole, D-198) +
the `.30/.48/.50/.35/.36/.42/.52/.54` cross-module type-identity/finality negatives
(**ADR-gated** D-202). The per-op `struct_*/array_*/ref_*` files returning
`error.NotMigrated` are NOT behavior gaps — they fall back to the legacy switch
(`dispatch_collector.zig:280`); the real impl lives in `lower.zig` / `validator.zig`
/ `mvp.zig` and the corpus is green through it. (The GC-survey-subagent's "all gc
ops are 3-line stubs → implement struct.new" was a MISREAD of the migration-marker
architecture — verified against the green corpus + ref_test.zig also returning
NotMigrated while ref.test passes fixtures.)

**Remaining Phase-10 work, by bucket:**
- USER-GATED (high value): formal Phase 10 close (close-eligible); GC ADR-0123
  (D-195 typed-ref `0x63/0x64` parser) + ADR-0126/D-202 (cross-module finality)
  `Proposed → Accepted` flips → unblock the function-references corpus + the 8
  ADR-gated gc negatives.
- Deferred: `.17` exotic fixture; realworld capstones (wasm_of_ocaml/emscripten_eh/
  dart/hoot — toolchains unprovisioned); memory64 >4GiB offset.
- **Autonomous (low value, refactor/perf)**: gc op **per-op-file migration**
  (ROADMAP 10.G `op_gc.zig`/`op_i31.zig` 本実装 — move handlers from the legacy
  switch into the `NotMigrated` per-op files; behavior-preserving, verified by
  `dispatch_consistency_audit` + green corpus); `gc_stress_runner` / `eh_frequency_runner`
  本実装 (perf scaffolding).

Next driving chunk = **start the gc per-op-file migration bundle**. Step 0: read an
ALREADY-migrated op's per-op file to learn the handler ABI (signature + how it
reaches the operand stack / runtime ctx), then migrate ONE gc op (e.g. `struct.new`)
from the legacy switch into its per-op handlers, asserting test-all neutrality
(green pre+post) + the dispatch-consistency delta. If the migration handler ABI
turns out to require a large cross-cutting change → re-scope to a bucket-3 touchpoint
(the user-gated paths above are higher value). NOTE smell: `runner.zig` 1168 lines
(soft WARN) — test sibling extraction is a future refactor.
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
