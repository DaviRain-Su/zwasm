# v128 spill-aware codegen: 4 templates + just-in-time reload + fixture gotchas

**Date**: 2026-06-19

## Problem (D-034 arc, x86_64-only)

A JIT SIMD op handler that resolves a v128/scalar operand via **bare `resolveXmm`**
(`resolveFp`/`resolveGpr`) returns `UnsupportedOp` when that operand spills to a
stack slot under high register pressure. arm64 was already spill-aware (shared
`qLoad/qDef` helpers); x86_64 had ~18 gap sites. The x86_64 scratch budget is
tight: only **2 FP stage regs (XMM14/XMM15)** + the reserved **XMM7** + the op's
`dst`. There is NO PMULUDQ/PSHUFD memory form. **Reject a global 3rd-stage-XMM
pool cut** (perf + exotic).

## The 4 reusable templates (pick by the op's internal-scratch count)

1. **3-operand template** (cmp/ne/extmul-low/pmin-pmax — 0–1 internal scratch):
   each operand → its home reg, or a stage (XMM14/15) when spilled; `dst` → home,
   or **XMM7** when the result spills; flush XMM7→slot at the end. The D-066
   `dst==operand` home-alias stash fires **only when `dst` is a home reg** (a
   spilled result lands `dst` on XMM7, where a home operand can never alias it),
   so the **no-spill emit is byte-identical** (unit tests stay green).
2. **XMM7-park** (neg/abs — 1 internal scratch): move the op's own scratch to XMM7,
   freeing BOTH stages for src(stage0) + dst(stage1).
3. **dst/stage-as-load-temp** (extmul-high, i64x2-extmul — both stages internal,
   operand read once): load the spilled operand INTO `dst` (consumed before dst is
   written) or the not-yet-used stage.
4. **Just-in-time reload** (i8x16/i64x2 shifts, swizzle, shuffle, popcnt, i64x2.mul
   — both stages internal AND operand read 2–3×): do NOT keep a spilled operand in
   a persistent reg; **reload it from its RBP-disp slot into a stage at each use**,
   so only `dst`→home/XMM7 + the 2 stages are ever live. When the op has
   byte-asserting unit tests (i64x2.mul), use a **two-path**: `if (all-reg) {original
   recipe verbatim} else {spill restructure}` — keeps the golden bytes, adds spill.

Helpers (file-local, candidates to consolidate into a shared `op_simd.zig` pub set):
`resolveOrLoadV128` / `loadV128Into*` / `dstHomeOrXmm7*` / `store*IfSpilled*`.

## Fixture methodology (two gotchas that each cost real time)

- **Force the spill**: the live-stack trick — push ≥pool-size (**13**) live v128
  (`v128.const`) before the op, then OR/drop-chain to fold them away after; OR a GC
  `array.new_fixed`/`array.get` round-trip. The op's operand (highest vreg) spills.
- **GOTCHA — verify expected values via wasmtime, NOT interp**: the interp has no
  SIMD, so use `wasmtime --invoke f -W gc=y -W function-references=y <f>.wasm`.
- **GOTCHA — double-check the SIMD opcode byte**: a hand-inlined `i32x4.gt_s` typed
  as `0x37` (= `i32x4.eq`) instead of `0x3b` faked a full miscompile-hunt
  (disassembly + capstone) before it turned out to be a one-byte fixture typo.
  i32x4 cmp opcodes: eq=37 ne=38 lt_s=39 lt_u=3a gt_s=3b gt_u=3c le_s=3d ge_s=3f.

## Verification

Local x86_64 red→green via `zig build test -Dtarget=x86_64-macos` (Rosetta, per
`rosetta-x86_64-local-jit-unit-test`); arc closed @411dd1e14, ubuntu + windows GREEN.
See also `x86_64-regalloc-fp-spill-origin-mismatch` (the regalloc origin bug this
arc's pressure first surfaced).
