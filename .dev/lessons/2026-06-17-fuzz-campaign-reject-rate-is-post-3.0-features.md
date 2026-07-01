# Fuzz campaign: a ~40% reject rate is post-3.0 smith features, not a bug

**Date**: 2026-06-17

## What happened

Ran a §14.3 fuzz campaign on the Mac host: `FUZZ_N=800 bash
scripts/gen_fuzz_corpus.sh campaign` → 808 `wasm-tools smith` modules → the
`zwasm-fuzz-loader` (decode → `Engine.compile` → instantiate). Result:
**808 processed, 486 compiled (424 instantiated), 322 rejected, 0 crashes**.

The 322 (~40%) compile-rejects looked alarming — `wasm-tools smith` emits
*valid* modules, so "zwasm rejects 40% of valid modules" would be a spec bug.

## Resolution (not a bug)

`wasm-tools smith`'s default config enables MANY proposals beyond Wasm 3.0
(threads/shared-everything, relaxed-simd, wide-arithmetic, custom-page-sizes,
stack-switching, …). The random input bytes make ~40% of generated modules use
at least one post-3.0 feature, which zwasm (Wasm 3.0) **correctly** rejects at
validation. The authoritative false-rejection guard is the official Wasm 3.0
spec testsuite (`test-spec`, 25539/0) — it exhaustively pins valid-3.0-module
ACCEPTANCE, so a real false-rejection of 3.0 constructs would fail there first,
not in a fuzz campaign.

Pitfall: `zwasm run <smith.wasm>` exits nonzero for almost ALL smith modules
("no exported function found" / "missing import"), so CLI exit code is NOT a
compile-reject signal — only the loader's `Engine.compile` reject count is.

## Rule

- A fuzz campaign's value is **0 crashes** (decode/compile/instantiate
  robustness on diverse input), NOT the reject rate. A high reject rate is
  expected (post-3.0 smith features).
- To interpret "did acceptance regress?", trust `test-spec` (the 3.0 acceptance
  oracle), not the campaign reject count.
- If a campaign ever reports a NON-zero crash count → real bug (panic /
  `unreachable` / SEGV / hang); minimise the input and add it to the committed
  seed corpus.

## Related

- §14.3 fuzz workflow; `test/fuzz/fuzz_loader.zig` (crash = finding contract).
- `2026-06-08-impl-limit-must-match-spec-ceiling-and-corpus` (decoder limits).
