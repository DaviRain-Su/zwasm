# The interpreter does NOT execute SIMD — SIMD is JIT-only

**Observation (2026-06-20):** zwasm's interpreter has **no SIMD handlers at
all**. Any v128 op — `i32x4.splat`, `v128.load32_splat`, etc. — traps
`unreachable_` via the dispatch null-slot (`src/interp/dispatch.zig:43`,
`table.interp[idx] orelse return Trap.Unreachable`). The per-op SIMD files
(`src/instruction/wasm_2_0/*_splat.zig`) are inert `n`/`NotMigrated` metadata
anchors that are NOT installed into the interp table. Confirmed empirically:
`--engine interp --invoke f` on `i32.const 5 i32x4.splat i32x4.extract_lane 0`
→ `trap unreachable_`; `--engine jit` → `5`.

**Why this is by design, not a bug:** the SIMD spec assertion runner
(`test/spec/simd_assert_runner.zig`) is built on `zwasm.engine.runner` (the JIT
runner) + `engine.codegen.shared.entry` (the JIT entry) — SIMD conformance
(`simd_assert_runner: 25075 passed`) is achieved through the **JIT backend**. The
interp is the portable, non-SIMD engine; the JIT is the SIMD engine. Realworld
interp 56/56 holds because those fixtures are compiled without `+simd128`.

**Consequences:**
- Comparing interp-vs-JIT on a SIMD-using function is meaningless — the interp
  bails `unreachable_` at the first v128 op while the JIT runs it. The exec
  differential fuzzer (`test/fuzz/fuzz_exec.zig`) MUST skip these: it treats an
  interp `unreachable_` trap that the JIT does NOT mirror as **incomparable**
  (an interp unimplemented-op bailout, not a JIT miscompile). A genuine
  `unreachable` instruction traps on BOTH engines, so this skip is sound.
- Don't "fix" an interp SIMD `unreachable_` by implementing SIMD in the interp —
  that's a deliberate ~236-op architecture boundary (JIT-only SIMD), not a sweep
  gap. ADR-0128's "100% both backends" is the non-SIMD corpus on both + the SIMD
  corpus on the JIT runner.
- Found via the FUZZ_N=6000 exec-differential campaign (the trap-kind compare
  flagged interp `unreachable_` vs JIT `oob_memory` on `smith_5619` — the JIT was
  correct; the interp's `unreachable_` was its SIMD-absence, not a bug).

Related: [[2026-06-02-instruction-wasm3-stubs-are-inert-metadata-anchors]].
