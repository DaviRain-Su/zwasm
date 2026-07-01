# A correctness fix that shifts regalloc pressure can expose a latent arch-specific spill-staging bug — and `test-spec` ≠ the wasm-2.0-assert runner

**Context**: D-330. The regalloc strict-`<` expiry fix (`6790c204`) was green on Mac
arm64 (`zig build test` + `test-spec`) and locally x86_64-Rosetta, so it was pushed.
The ubuntu `test-all` gate then FAILED: `spec_assert_runner_non_simd: 25408 passed, 29
failed` — all `float_exprs no_fold_*_select`. Caught at the NEXT resume's Step 0.7.

**Two lessons:**

### 1. The bug — x86_64 `emitFpSelect` clobbered a spilled cond before testing it
x86_64 has no FP conditional-select, so `emitFpSelect` stages: `cond_r =
gprLoadSpilled(cond, stage 0)`; `MOVQ r_a, xmm_val1`; `MOVQ r_b, xmm_val2`; `TEST
cond_r`; `CMOV`. But `gprLoadSpilled(stage 0)` returns `spill_stage_gprs[0] == r_a`
**when cond is spilled** — so `MOVQ r_a, xmm_val1` overwrote cond BEFORE the TEST →
the select tested val1's bits, not cond. Latent for as long as cond stayed in a
register; the `<` fix raised pressure by ~1 slot, spilled cond, and exposed it. Fix:
emit `TEST cond` immediately after loading it, before the MOVQ stages (MOVQ/MOVD don't
touch EFLAGS). The x86_64 INT select (`emitSelectCtx`) already did this — fp now matches;
arm64 uses atomic `CSEL` (reads cond + both operands in one instruction) → never affected.
Rule: when an emit STAGES an operand through a fixed scratch reg, any later reuse of that
reg before the operand is consumed is a clobber — and it only bites once regalloc spills
that operand. Test the staged value (or copy it out) BEFORE reusing the stage reg.

### 2. The gate gap — `zig build test-spec` does NOT run `zwasm-spec-wasm-2-0-assert`
`test-spec` passed locally while the wasm-2.0-assert corpus (a SEPARATE exe,
`zwasm-spec-wasm-2-0-assert <dir>`, only run under `test-all`) had 29 fails. And
`gate_commit.sh --fast` runs only `zig build test`. So a codegen/regalloc change can pass
every local pre-push gate and still break spec on the remote. Rule: for ANY
regalloc/codegen-emit change, run `./zig-out/bin/zwasm-spec-wasm-2-0-assert
test/spec/wasm-2.0-assert` (+ the simd one) locally BEFORE pushing — and prefer a
cross-arch check (x86_64-macos + Rosetta) since spill/staging bugs are arch-specific and
x86_64 (4 GPRs) spills sooner than arm64 (8). The 3-host gate caught it, but at the cost of
a red remote + a revert-or-fix-forward decision; local cross-arch is cheaper.

Cite: D-330, `6790c204` (regalloc fix), `cccb2313` (fp-select fix),
[`2026-06-15-regalloc-boundary-coalesce-read-after-write`](2026-06-15-regalloc-boundary-coalesce-read-after-write.md).
