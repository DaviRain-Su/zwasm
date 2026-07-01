# wasmtime misc_testsuite differential campaign — Phase I findings

> **Doc-state**: ACTIVE
> ADR-0192. Sweep harness: `scripts/wasmtime_misc_sweep.sh` (+ shared distiller
> `scripts/wast_to_manifest.py`). Upstream: wasmtime @897aa00d (2026-06-16).

## Raw sweep result (C-API runtime runner) — 312 .wast

PASS 139 · FAIL 164 · CONVFAIL 0 · EMPTY 9. `wasm-tools json-from-wast` lowered
every file (0 conversion failures — even component text).

FAIL by bucket: component-model 60 · gc 55 · simd 7 · memory64 7 ·
component-model-threading 7 · winch 4 · function-references 4 · threads 3 ·
custom-page-sizes 3 · tail-call 1 · multi-memory 1 · + 12 top-level core.

## The pivotal finding — wrong vehicle for ~130 of the 164

`test/runners/wast_runtime_runner.zig` instantiates through the **C-API**
(`wasm_module_new`/`wasm_instance_new`). The C-API is the classic upstream
`wasm.h` MVP surface (interp-only; no GC/typed-ref/component reflection —
wasmtime exposes GC only via its own `wasmtime.h` extensions, not `wasm.h`).
So:

- **gc (55)**: `wasm_module_new` succeeds (GC *validates*) but
  `wasm_instance_new` returns null → `InstanceAllocFailed`. zwasm's GC engine
  is **362/0 green** through the *native* runner (`spec_assert_runner_wasm_3_0`
  → `engine.runner`, NOT the C-API). → harness artifact, NOT a core gap.
- **component-model (+threading) (67)**: the emitted binaries are **component**
  binaries; zwasm's core-module decoder correctly rejects them
  (`ModuleAllocFailed`). Out-of-scope as a core .wast (needs the component
  runtime, which is a separate surface). → not a core spec gap.

These ~122 are not core-engine gaps. They are the C-API runner being unable to
exercise what the native engine already runs.

## The genuine candidate gaps (C-API-runnable subset that actually FAILed)

Signatures in the subset that DID instantiate via C-API (need per-file triage,
Phase II/III): 11× `assert_trap` trap-kind mismatch · 10× `assert_return` value
mismatch · 5× "assert_return missing export name" · 3× `unlinkable` ·
1× integer-overflow panic (`gc/issue-13034`, C-API path). Some are distiller
artifacts (the distiller drops `nan:canonical`/v128/ref expected values →
`canonicalize-nan-scalar`'s 2 fails are reinterpret asserts that DID distil;
verify they aren't NaN-encode artifacts). top-level core 12 incl. embenchen_*
(committed corpus skips their env-import `.1.wasm`; the raw sweep doesn't).

## Next step (Phase I → real gap list)

Re-route the proposal/gc/simd/typed-ref subset through the **native engine
runner** (the `spec_assert_runner_*` family — GC/v128/typed-ref/EH-capable,
`wasm_3_0_manifest.zig` directive set) instead of the C-API runner. Only the
residual failures *there* are real core gaps to root-cause + fix (TDD, no
blanket skip). The C-API runner stays the vehicle for the core/non-GC subset.

Out-of-scope-as-core-.wast (documented, not silently skipped): `winch/`
(wasmtime baseline-compiler codegen), `component-model*/`,
`shared-everything-threads/`.

## Reproduce

```sh
bash scripts/wasmtime_misc_sweep.sh            # all 312 → /tmp/wmt-sweep/
bash scripts/wasmtime_misc_sweep.sh gc simd    # buckets only
# per-FAIL runner output: /tmp/wmt-sweep/<name>.log
```
