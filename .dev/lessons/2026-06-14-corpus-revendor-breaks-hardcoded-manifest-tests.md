# Re-vendoring a spec corpus can break HARDCODED unit tests (not just the spec runner)

**2026-06-14** — surfaced during the wg-3.0 re-vendor (P-3.0 tail-call slice).

## Observation

Re-vendoring `test/spec/wasm-3.0-assert/tail-call/` from wg-3.0 (return_call +3 /
return_call_indirect +4 asserts) passed `zig build test-spec-wasm-3.0-assert`
(the spec assert RUNNER, "0 failed") — but **failed `zig build test-all` on
ubuntu** with 2 failures in `test/spec/wasm_3_0_manifest.zig`:

- `runOne e2e: return_call.0.wasm type-i32 () -> i32:306 (10.TC verify)` — an e2e
  test asserting a SPECIFIC value computed from a SPECIFIC corpus module.
- `tail-call bisect: enumerate 31 assert_returns ... (D-187 regression marker)` —
  a test that hardcodes the corpus's assert COUNT (31).

The re-vendor legitimately changed the corpus (new asserts, re-baked modules), so
these pinned expectations went stale.

## Why it was missed

I ran only `test-spec-wasm-3.0-assert` (the runner that CONSUMES the corpus and
reports conformance) — it showed green. The hardcoded tests live in the **`zig
build test` unit binary** (`wasm_3_0_manifest.zig`), a DIFFERENT suite that pins
corpus structure/values. The spec runner and the hardcoded markers check
different things.

## Rule

**After ANY `test/spec/` corpus re-vendor/re-bake, run the FULL `zig build test`
(or `test-all`), not just `test-spec-<layer>`.** Some corpora have hardcoded
companion tests in `wasm_3_0_manifest.zig` (e2e value-asserts + D-187-style
"enumerate N assert_returns" regression markers) that must be updated in the
SAME commit when the corpus count/content changes. The gc slice (b8e8b16c) had
no such pinned test so it passed; tail-call did → reverted (`a981e5d8`).

Implication for D-327 / full wg-3.0 re-vendor: re-vendoring tail-call (and likely
others) must ALSO update the `wasm_3_0_manifest.zig` hardcoded counts/values.
