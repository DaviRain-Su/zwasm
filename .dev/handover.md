# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `38afcd7a` (cyc222). **`devShells.gen` (cyc221) + 2 REAL Rust fixtures**
  (user-directed あるべき論: nix `devShells.gen` separate from `default`, kept off the
  ubuntu/windows test hosts; generated `.wasm` COMMITTED → run via the Zig edge-runner, NO
  toolchain on test hosts — `.dev/toolchain_provisioning.md`). realworld/p10 runner = 4:
  clang_musttail=15, clang_wasm64=42, `rust_loop_sum`=45 (loop, cyc221),
  `rust_fib`=55 (recursion via `#[inline(never)]` — real call/return, NOT folded; cyc222).
  **Cross-host model ubuntu-VERIFIED** (Step 0.7 `OK 369cfc91`: the rust `.wasm` ran on
  x86_64 with no rustc there). CLAUDE.md + flake.nix point at the provisioning doc.
- **7 cross fixtures** (`test/edge_cases/p10/cross/`): call_ref/return_call/EH × memory64,
  EH × call_ref, multivalue × call_ref, call_indirect × memory64, SIMD × call_ref. All Mac-green.
- D-208 (cyc213) + D-209 (cyc214) fixed + ubuntu-verified. **10.P: 16 PASS / 8 SKIP / 0 FAIL**
  → close-eligible. I14 deferred (Phase-13 type-reflection c_api); D-206 deferred (≈4-6 cyc
  native cross-module JIT bridge; existing cross-module dispatch is interp-routed; not close-required).
- **cyc223**: extended the cyc216 caching fix — the 4 `test/realworld/wasm/` runners
  (`run_realworld{,_run,_run_jit,_diff}`, all in test-all) had the same `addArg(dir-string)`
  false-coverage gap (missed in cyc216) → `has_side_effects=true` (`f424d7e8`). The 55-fixture
  realworld corpus (C/C++/tinygo/cljw — already has tinygo_sort!) is now protected; 45/55 pass,
  10 SKIP-WASI (→ Phase 11). The realworld + cross veins are mature.
- **Step 0.7 on resume**: cyc223 build.zig change (`f424d7e8`) → ubuntu kicked. VERIFY
  (`tail /tmp/ubuntu.log`): realworld runners re-run + pass on x86_64. rust_fib already
  ubuntu-verified (`OK 36547ac2`).

## Active task — rust_data realworld fixture (static data + memory-read codegen)  **NEXT**

The last genuinely-distinct rust codegen path my p10 fixtures don't cover: a `#![no_std]`
`static DATA: [i32; N]` summed via indexed reads → exercises **data-segment init + memory
loads** through real rustc output (where subtle data/memory bugs hide), via `runI32Export`.
Land `test/realworld/p10/rust_data/` (gen via `nix develop .#gen`). Smallest red: sum a
static array → known i32. **Note**: tinygo/go/emcc-libc need WASI+instantiation → the
diff_runner corpus (`test/realworld/wasm/`, now un-cached); but that corpus is already mature
(tinygo_sort etc.), so marginal — defer.
**User touchpoint (held, prominent)**: Phase 10 close-eligible (10.P 0 FAIL); the high-value
JIT work + the gen-shell realworld infra are done. The tractable fixture veins (cross,
realworld) are now MATURE. The substantive remaining autonomous work is DEEP + not-close-
required (D-206 cross-module bridge ≈4-6 cyc; 10.G GC JIT extreme) OR Phase-11-scoped (the 10
SKIP-WASI). The formal Phase-10 close (→ Phase 11) is the genuinely highest-value next step
and is a user project-direction decision. A user check-in is high-value here. NOT a stop —
loop continues on tractable distinct fixtures; re-arm holds.
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
