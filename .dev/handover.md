# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — CLOSE-ELIGIBLE** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `d8c26eb1` (cyc221). **`devShells.gen` introduced + first REAL Rust fixture**
  (user-directed: install absent toolchains, prefer nix, efficient cross-host, v1 あるべき論).
  `flake.nix` gains a SEPARATE `devShells.gen` (`nix develop .#gen`) with emcc / tinygo /
  rustc-wasm (rust-overlay `.minimal`) / go / clang+lld — kept OUT of `default` so ubuntu/
  windows test hosts stay lean. **Cross-host model** (`.dev/toolchain_provisioning.md`):
  generated `.wasm` is a COMMITTED artifact → test hosts run it via the Zig edge-runner, NO
  toolchain there (Mac-generation-only). Landed `test/realworld/p10/rust_loop_sum/loop_sum`
  (rustc 1.96.0, `#![no_std]` loop-sum → 45). realworld/p10 runner: clang_musttail=15,
  clang_wasm64=42, rust_loop_sum=45. CLAUDE.md points at the provisioning doc.
- **7 cross fixtures** (`test/edge_cases/p10/cross/`): call_ref/return_call/EH × memory64,
  EH × call_ref, multivalue × call_ref, call_indirect × memory64, SIMD × call_ref. All Mac-green.
- D-208 (cyc213) + D-209 (cyc214) fixed + ubuntu-verified. **10.P: 16 PASS / 8 SKIP / 0 FAIL**
  → close-eligible. I14 deferred (Phase-13 type-reflection c_api); D-206 deferred (≈4-6 cyc
  native cross-module JIT bridge; existing cross-module dispatch is interp-routed; not close-required).
- **Step 0.7 on resume**: cyc220 SIMD fixture (`7d826f3c`) + cyc221 gen-shell+rust (`d8c26eb1`)
  pushed; ubuntu kicked. VERIFY (`tail /tmp/ubuntu.log`): 7 cross + rust_loop_sum pass on x86_64
  (the rust `.wasm` is a committed artifact, runs without rustc on ubuntu). FAIL ⟹ investigate
  (fixture-only or a real rust-codegen miscompile on x86_64).

## Active task — 2nd Rust realworld fixture (distinct codegen: recursion)  **NEXT**

Real-toolchain bug-finding vein (cf. clang_wasm64→D-209). The loop-sum may have const-folded;
next a Rust fixture exercising a DISTINCT codegen path that won't fold: a `#![no_std]`
recursive `test()->i32` (e.g. fib(10)=55 or factorial), via `nix develop .#gen` →
`rustc --target wasm32-unknown-unknown -O --crate-type=cdylib`, JIT-run through the edge-runner.
Land `test/realworld/p10/rust_<slug>/`. **Toolchain note**: runI32Export only runs simple
no-arg-i32-no-WASI modules (rust `#![no_std]`, clang `-nostdlib`). go/tinygo/emcc-libc modules
need WASI + instantiation → they belong in `test/realworld/wasm/` under the **diff_runner**
(`test-realworld-diff`, byte-diffs stdout vs wasmtime), a separate follow-on. emcc
`-sMEMORY64=1` (planned `clang_wasm64/` big-alloc) once its cache builds.
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
