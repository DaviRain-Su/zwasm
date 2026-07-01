# `zig build test` ≠ `test-all` — adding a union variant can break a latent spec-runner exe

**Date**: 2026-06-15 · **Area**: build targets, exhaustive switches, union variants, test-all

## What happened

Unit C (`58e3f46a`) added `.stream`/`.future` variants to `canon.CanonType`. I
updated every exhaustive `switch` the compiler flagged — but only under local
`zig build test`. `test/spec/component_model_assert_runner.zig` (the
`zwasm-component-spec-assert` exe) has its own `switch (ct: CanonType)` and is
built **only by `test-all`**, not by `zig build test`. So the break stayed
**latent for ~5 commits** (Unit C → ζ1) — every local Step-5 gate was green —
until an ubuntu `test-all` run finally reached a terminal FAIL.

Compounded by a second factor: the per-turn ubuntu kicks were slower than the
~60s `/continue` cadence, so each Step 0.7 saw the gate mid-run (all-PASS so
far) and never the terminal line — the latent build break was invisible for
several turns.

## Rules

1. **Adding a variant to a union that has switches in `test/` exes** (CanonType,
   DefType, Canon, EventCode, …) → `grep -rn "switch" test/` + grep the variant's
   sibling arms (`.own =>` / `.borrow =>`) across `test/`, not just `src/`.
   `zig build test` compiles `src/` + its inline tests; the spec-runner exes
   (`component_model_assert_runner`, `spec_assert_runner`, wast runners) are
   separate `build-exe` targets only in `test-all`.
2. For a campaign that touches a widely-switched union, **run `test-all` locally
   at least once** before relying on remote verification — it's the only local
   build that compiles the runner exes.
3. A remote gate whose runtime exceeds the resume cadence can hide a real failure
   behind "mid-run, all-PASS" — when in doubt, let one finish (or run it locally).

Fix: `.stream, .future => return error.BadValue` (async handles aren't manifest
literals). test-all green (`5e0610a1`).
