# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `e71d6a0a` (cyc228). This session (cyc213-229) delivered, all ubuntu-verified:
  D-208 (x86_64 funcref-null trap: `usesRuntimePtr` gap) + D-209 (memory64 memarg-offset u64)
  JIT bug fixes; 2 false-coverage caching fixes (`has_side_effects` on all edge+realworld
  runners); the user-directed nix **`devShells.gen`** reproducible toolchain provisioning
  (`.dev/toolchain_provisioning.md`); the cyc224 **shadow-stack unlock** (setupRuntime now
  evaluates const global inits → real `-O` rust/clang code runs); a complete real-toolchain
  **realworld/p10 matrix** (8 fixtures: rust loop/recursion/data/sort + clang musttail/wasm64/
  -O0-int/-O0-fp); 7 cross-feature edge fixtures; a pre-close audit (scaffolding coherent).
- **10.P: 16 PASS / 8 SKIP / 0 FAIL → close-eligible.** Tractable autonomous veins EXHAUSTED.
- **Step 0.7 on resume**: cyc228 was docs/debt-only (no kick); cyc229 is Step-0/docs-only (no
  kick). Last green: `OK (HEAD=0aad48c6)` (8 realworld/p10 pass x86_64). Next CODE chunk kicks ubuntu.

## Active bundle

- **Bundle-ID**: D-206-cross-module-TC. **Cycles-remaining**: ~2-3.
- **cyc229 Step-0 GROUND-TRUTH (re-scopes the wrong cyc218 survey)**: cross-module CALL via JIT
  ALREADY works natively + is spec-validated. The spec runner's `resolveCrossModuleImports`
  (`spec_assert_runner_base.zig:1476`) emits a NATIVE bridge thunk via `shared/thunk.zig:emitThunk`
  (call-and-return: save pinned reg, swap runtime_ptr→callee_rt, BLR/CALL callee_entry, restore,
  RET-to-importer) into `host_dispatch_base[import_idx]`. (The interp-routed
  `api/cross_module.zig:thunk` is the C-API *Linker* path, NOT the JIT path — cyc218 confused them.)
  So D-206 needs only: (1) a 2-module return_call TEST (no tail-call cross-module test in the
  spec corpus), (2) the tail-bridge EMIT — per ADR-0112 D4: marshal args, `frame_teardown(A)`,
  tail-jump `BR/JMP` to the callee with X0/RDI=callee_rt (so the callee's RET goes to A's caller).
  The existing `emitThunk` is CALL-shaped → return_call needs a NEW tail bridge (inline per D4,
  OR a tail-variant thunk). Reject site: `op_tail_call.emitDirectReturnCall` arm64:157 / x86_64:143
  (`if ins.payload < num_imports → UnsupportedOp`).
- **Continuity-memo / harness gap**: a `runI32ExportTwoModule` test reuses `compileWasm` +
  `resolveCrossModuleImports` + `entry.callI32NoArgs`; the MISSING piece is a dispatch-override
  (the spec runner's `makeJitRuntime` has `dispatch_override: ?[]const usize`; `setupRuntime`
  does NOT). For the tail-bridge, the emit needs callee_rt+callee_entry — host_dispatch_base[i]
  holds the THUNK addr (embeds them in its literal pool), so either expose them at resolve time
  OR add a tail-variant thunk reachable from the importer.
- **Exit-condition**: a 2-module fixture where A's exported `test` does `return_call` to a
  B-imported func, JIT-executed → expected i32, both arches, ubuntu-verified.

## Active task — D-206 step 1: multi-module JIT test harness + baseline cross-module call  **NEXT**

Build the harness (test file, zone-exempt): instantiate B, resolve A's func-import→B's JIT entry
(`resolveCrossModuleImports` is pub in spec_assert_runner_base; reuse or extract to a shared
location), JIT-run A's `test`. Add a dispatch-override path (the gap). Smallest RED→GREEN: A does
a normal `call $imported` → B returns a const → verify cross-module CALL works through the harness
(baseline). Then step 2 = the `return_call` test (REDs on the reject) + the tail-bridge emit.
NOT close-required (interp covers it); completes the tail-call JIT arc (D-205→D-208→D-206).
**User touchpoint (held)**: Phase 10 close-eligible (10.P 0 FAIL). Formal close (→ Phase 11) is
a high-value user decision; D-206 is the loop's autonomous continuation, re-armable to the close
at any user signal. Re-arm holds.

## §10 close map + open

Spec-corpus rows mature; 10.P close-eligible (0 FAIL). realworld/p10 matrix complete (8). gc .17
funcref-RTT (D-198) deep defer; funcrefs 34/39 (5 RTT-gated); 10 SKIP-WASI → Phase 11.
D-197 (validate-error surfacing ad-hoc); D-209 residual (>4GiB memory64 offset, payload u32).

## Key refs

- ADR-0066 (cross-module bridge thunk); ADR-0112 D4 (cross-module tail-call); ADR-0111 (memory64);
  ADR-0114 (EH). `flake.nix devShells.gen` + `.dev/toolchain_provisioning.md`.
- Lessons: `2026-05-30-{jit-funcref-tail-call-codegen-recipe, clang-wasm-realworld-toolchain-recipe,
  edge-runner-fixture-cache-false-coverage}`. ROADMAP §10; `.dev/phase_log/phase10.md`.
