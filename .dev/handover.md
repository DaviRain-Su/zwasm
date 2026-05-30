# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `eddb4652` (cyc224). **Real-toolchain realworld fixtures + a real harness bug fix.**
  nix `devShells.gen` (cyc221, user-directed あるべき論; separate from `default` so test hosts
  stay lean; generated `.wasm` COMMITTED → run via the Zig edge-runner, NO toolchain there;
  `.dev/toolchain_provisioning.md`). realworld/p10 runner = 5: clang_musttail=15, clang_wasm64=42,
  rust_loop_sum=45 (loop), rust_fib=55 (recursion), **rust_data=31** (static-array sum + shadow
  stack). **rust_data surfaced + fixed a real harness bug** (`eddb4652`): `setupRuntime` left
  defined globals at 0 instead of evaluating their init-exprs → `__stack_pointer`=0 → shadow-stack
  `SP-n` wrapped OOB → trap. Fix evaluates const global inits → **shadow-stack modules now run**
  (real `-O` rust/clang code, not just trivial fixtures). The clang-recipe lesson's "-O0
  shadow-stack traps" limitation is lifted. Cross-host model ubuntu-verified (cyc222 `OK 36547ac2`).
- **7 cross fixtures** (`test/edge_cases/p10/cross/`): call_ref/return_call/EH × memory64,
  EH × call_ref, multivalue × call_ref, call_indirect × memory64, SIMD × call_ref. All Mac-green.
- D-208 (cyc213) + D-209 (cyc214) fixed + ubuntu-verified. **10.P: 16 PASS / 8 SKIP / 0 FAIL**
  → close-eligible. I14 deferred (Phase-13 type-reflection c_api); D-206 deferred (≈4-6 cyc
  native cross-module JIT bridge; existing cross-module dispatch is interp-routed; not close-required).
- cyc223: caching fix → realworld/wasm runners (`f424d7e8`). cyc224: setupRuntime global-init
  fix → shadow-stack unlocked + rust_data (`eddb4652`, ubuntu-verified `OK c05eb57c`).
  cyc225: `rust_bubble_sort`=4 (real algorithm: nested loops + array load/store on the shadow
  stack — confirms the unlock handles real rustc algorithmic codegen; `9e4d0cfe`). realworld/p10
  = 6 fixtures, all green. **Stale-exe pitfall** recurs: isolated `find`-by-grep can grab a
  pre-fix exe → use `zig build` EXIT + the exe passing `data_sum=31`.
- cyc226-227: clang `-O0` `arr_sum`=39 + `fp_sum`=77 → realworld/p10 = 8 fixtures, all green
  (real-toolchain matrix COMPLETE: rust loop/recursion/data/sort + clang musttail/wasm64/-O0-int/-O0-fp).
- cyc228: **pre-close audit** (`72cd2c05`) — scaffolding coherent (lessons INDEX'd, D-207/8
  deleted cleanly, doc cross-refs resolve, SHAs valid); 10.P re-run = 16 PASS / 8 SKIP / 0 FAIL
  (close-eligible holds); deleted discharged D-205. Tractable autonomous veins now EXHAUSTED.
- **Step 0.7 on resume**: cyc227 clang_O0_fp_sum (`0aad48c6`) ubuntu kick was in-flight; cyc228
  is docs/debt-only (no kick). VERIFY (`tail /tmp/ubuntu.log`): `OK (HEAD=0aad48c6)` (8
  realworld/p10 pass on x86_64). The next CODE chunk (D-206) kicks ubuntu.

## Active bundle

- **Bundle-ID**: D-206-cross-module-TC (re-opened cyc228 — engaged now that all tractable
  prep is exhausted; the loop directs deep autonomous work).
- **Cycles-remaining**: ~3 (measurable-step decomposition; architectural 3-cycle cap applies).
- **Continuity-memo**: (1) a multi-module JIT test harness — GROUND-TRUTH the real cross-module
  link API (read the spec runner `test/spec/spec_assert_runner_base.zig` multi-module register/
  link path — NOT the cyc218 survey's confabulated `linkFunctionImport` name), write a 2-module
  test where module A JIT-calls a B-imported func (baseline; the existing cross-module dispatch
  is interp-routed via `host_dispatch_base`→`api/cross_module.zig:thunk`); (2) cross-module
  `return_call` native inline-bridge emit per ADR-0112 D4 (arm64 then x86_64) — the FIRST native
  JIT→JIT cross-module path. Current block: `op_tail_call.emitDirectReturnCall` rejects
  `ins.payload < num_imports`.
- **Exit-condition**: a 2-module fixture where module A's exported `test` does `return_call` to
  a B-imported func, JIT-executed → expected i32, both arches, ubuntu-verified.

## Active task — D-206 step 1: ground-truth cross-module link + multi-module JIT harness  **NEXT**

Step 0: read the spec runner's ACTUAL multi-module link code (`spec_assert_runner_base.zig`
RegisteredExporter + the `(register)` directive handler) + `src/zwasm/linker.zig` to find the
real cross-module func-import wiring (the cyc218 survey confabulated names). Step 1: add a
`runI32ExportTwoModule`-style helper (test file, zone-exempt) that instantiates B, links A's
import to B's export, JIT-runs A's `test` → i32. Smallest red: A does a normal `call $imported`
→ B returns a const → verify the cross-module call works through the harness (baseline before
the return_call bridge). NOT close-required (interp covers it); completes the tail-call JIT arc.
**User touchpoint (held)**: Phase 10 close-eligible (10.P 0 FAIL). Formal close (→ Phase 11)
remains a high-value user decision; D-206 is the loop's autonomous continuation, re-armable to
the close at any user signal. Re-arm holds.
**User touchpoint (held, prominent)**: Phase 10 close-eligible (10.P 0 FAIL). The real-toolchain
fixture vein is now PRODUCTIVE again (shadow-stack unlocked → real code finds real bugs, e.g.
cyc224). Deep not-close-required work (D-206 ≈4-6 cyc; 10.G GC JIT extreme) + the 10 SKIP-WASI
(Phase 11) stay deferred. The formal Phase-10 close (→ Phase 11) is a user project-direction
decision worth a check-in. NOT a stop; re-arm holds.
**User touchpoint (held)**: Phase 10 close-eligible (10.P 0 FAIL); formal close (→ Phase 11)
is a user project-direction decision worth a check-in. Tractable autonomous vein =
real-toolchain realworld fixtures (now unblocked). Deep not-close-required work (D-206, 10.G
GC JIT) stays deferred. NOT a stop; re-arm holds.

## §10 close map

Spec-corpus rows mature; 10.P close-eligible (0 FAIL). realworld/p10: clang_musttail +
clang_wasm64 + rust_loop_sum landed; go/tinygo/emcc are follow-ons (gen shell ready).
gc .17 funcref-RTT (D-198) deep defer; funcrefs 34/39 (5 RTT-gated). 10.P close = user touchpoint.

## Spec runner observable (cyc190, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=349/407 trap=96/100 invalid=60/60 ✅ malformed=1/1 skip=20
[multi-memory       ] return=407/407 trap=244/244
```
> gc residual: return=1 + trap=4 = type-subtyping.30/.48/.50. Use `--fail-detail`.

## Open questions / blockers

- D-197 (validate-error surfacing ad-hoc); D-206 (cross-module TC, deferred); D-209 residual
  (>4GiB memory64 offset, payload u32, deferred); I14 (c_api type-reflection → Phase 13).
- **Realworld toolchains**: `nix develop .#gen` (Mac only). `.dev/toolchain_provisioning.md`.

## Key refs

- ADR-0111 (memory64); ADR-0114 (EH); ADR-0112 (tail-call). `flake.nix` `devShells.gen`.
- Lessons: `2026-05-30-{jit-funcref-tail-call-codegen-recipe, clang-wasm-realworld-toolchain-recipe,
  edge-runner-fixture-cache-false-coverage}`. ROADMAP §10; `.dev/phase_log/phase10.md`.
