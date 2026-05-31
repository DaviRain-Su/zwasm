# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD**: §1 spec-corpus JIT mode — backbone (`0d9cddd7`) + fail-classification + **no-arg
  i64-result dispatch** (this chunk). Opt-in `ZWASM_SPEC_ENGINE=jit`. Mac aarch64: **pass=47
  fail=12 skip=1236** (no-arg result type now i32+i64 via `runI32Export`/`runI64Export`; i64
  flipped 7 from skip: +4 pass, +3 memory.grow64-trap fail). `jitErrorIsUnwiredShape`
  classifies compile/setup rejects → SKIP, executed-wrong → FAIL (shared-runtime bridge DROPPED
  — measured 0 of 96 were stale-state). Default stays interp → test-all unchanged.
- **Two execution paths (CODE-verified)**: spec corpus runs **interp by default**
  (`instance.invoke`→`_dispatch.run`, `instance.zig:169`); the **JIT path is now wired as an
  opt-in mode** (`ZWASM_SPEC_ENGINE=jit`, backbone above). The standalone `runI32Export`
  (`src/engine/runner.zig`) is the underlying no-arg-i32 JIT e2e primitive.
- **ADR-0128 + ADR-0127 both Accepted** — no remaining user gate; loop runs autonomously.
- **Watch**: `src/engine/runner.zig` at 1894 lines (soft-cap WARN; hard cap 2000). Extract the
  accumulating `runI32Export` e2e tests to a `test/` sibling (or FILE-SIZE-EXEMPT) before the
  next chunk that would breach 2000 (gate BLOCKS at 2000).

## Active task — Phase 10 → 100% (ADR-0128)  **NEXT**

Six workstreams (ADR-0128), value-prioritized (NOT §10 table-first):

1. **Spec-corpus JIT execution mode** (§1) — verification backbone — **NOW (Active bundle)**.
2. GC-on-JIT op emit (§2) — **DONE both arches**.
3. **ADR-0127 PHASE C** — cross-`Types` `canonicalEqual`; `gc/type-subtyping` 5→0.
4. Quick wins: **D-209** (lift leftover `>u32` offset check; payload already u64), **D-198**
   (rec-group subtype), **D-210** (cross-module proper-tail-call — arm64 prologue cohort-save).
5. **Realworld GC/EH/TC producers** (§5; flake.nix `#gen`): `wasm_of_ocaml` / `emcc
   -fwasm-exceptions` / `guile-hoot`.

## Active bundle

- **Bundle-ID**: `10.G-§1-jit-corpus-mode`
- **Cycles-remaining**: ~3
- **Continuity-memo**: ADR-0128 §1 — add a JIT EXECUTION path to the wasm-3.0 spec runner
  (`test/spec/spec_assert_runner_wasm_3_0.zig`): compile every fn → instantiate → invoke the
  exported fn via the JIT entry (NOT interp `instance.invoke`→`_dispatch.run`) → compare
  assert_return / assert_trap (wasmtime `tests/wast.rs` pattern). **Incremental** (the whole
  point of the should_fail list): start with the subset `runI32Export`/`callI32NoArgs` already
  supports — **no-arg i32-result exports GREEN**; track args / i64 / f32/f64 / v128 /
  multi-value / host-imports / typed-trap as a per-backend SKIP list (enumerated, NOT silently
  dropped). The general arg/result **dispatcher is a SEPARATE downstream chunk** — do NOT block
  the backbone on it. **Calling-convention 裏取り = RESOLVED** (2026-05-31, `entry.zig`
  read): JIT'd Wasm fns are invoked via the **C ABI** (`callconv(.c)`) — X0/RDI = `*JitRuntime`,
  then Wasm params in declaration order across GPR/FP banks per AAPCS64/SysV (int→X1../RSI..,
  FP→V0../XMM0..), NOT the operand stack. PROOF = the existing tested monomorphized helpers,
  esp. the mixed `callVoid_i64f32f64i32i32` family (`entry.zig:369-409`, exercises both arg
  banks) + the `entry.zig:367` comment. The dispatcher just builds the matching `callconv(.c)`
  fn-ptr per signature. Mode toggle: env `ZWASM_SPEC_ENGINE=jit` (simplest) — `build.zig:15`
  documents `-Dengine interp/jit/both` but it is NOT yet implemented.
- **Exit-condition**: ≥1 `assert_return` (no-arg i32) executes THROUGH the JIT + compares.
  ✓ **MET** (`0d9cddd7`). RED signal CLEAN (fail = JIT-executed-wrong only). Bundle continues
  for shape growth. Calling-convention 裏取り DONE (Continuity-memo — C-ABI). no-arg result
  type i32 ✓ + i64 ✓ (this chunk) wired.
- **NEXT chunk** = **no-arg f32/f64 result** — `callF32NoArgs`/`callF64NoArgs` EXIST + tested
  (`entry.zig:457/478`); add `runF32Export`/`runF64Export` (mirror runI64Export, gate `.f32`/`.f64`),
  widen `jitReturnEligible` to f32/f64, add an FP compare arm at the dispatch site. **The FP-specific
  work = the manifest's `nan:canonical`/`nan:arithmetic` expected-value handling** (reuse the interp
  path's FP-compare in this file; grep `nan:` / `expected_zv.f32`) + add boundary fixtures per
  test_discipline §1 (signed-zero, the two NaN classes, ±inf). THEN args (`callI32_i32`… exist) +
  multi-value. Secondary lever: multi-memory setup in
  `runI32Export`/`setupRuntime` (66 skips; needs JitRuntime per-memory base — likely its own
  chunk). Unemitted ops (11 skips: br_on_null / return_call_indirect / …) tracked by D-198 /
  tail-call / ADR-0127 PHASE C. **Shared-runtime state-bridge is NOT a chunk** — measured
  zero-yield (lesson `2026-05-31-spec-jit-corpus-fails-are-gaps-not-stale-state`).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 STALE (payload u64; lift leftover u32 check).
- **10.R** function-references — JIT emit present, corpus green; residual = D-198.
- **10.TC** tail-call — JIT matrix complete; residuals = D-210 + `wasm_of_ocaml`.
- **10.E** EH — JIT emit present; residuals = eh_frequency runner (I20), c_api tag
  accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit COMPLETE both arches; remaining = §1 JIT-corpus mode (this bundle)
  + ADR-0127 PHASE C + D-198 + gc_stress (I19) + dart/hoot (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

This turn landed the no-arg-i64 dispatch (code chunk: `runI64Export` in `src/engine/runner.zig`
+ runner widening). Classify=`unclear` → gated at `zig build test-all` (Mac green) + lint green;
ubuntu kicked at turn end against this turn's HEAD (`test-all`). Next `/continue`: `tail -3
/tmp/ubuntu.log`, expect `OK (HEAD=<this turn's tip>)`. On FAIL: revert this turn's commits to
the last ubuntu-verified code HEAD (`15d8c9cd`, the prior fail-classification turn, ubuntu-green).
Mac aarch64 primary; ubuntu confirms x86_64.

**Lesson (still live)**: `gate_commit.sh --fast` DEFERS `zig build test`/`lint` (Step 4/5 own
them) — the parent's full `zig build test` before push is the real gate.

## Key refs

- **ADR-0128** (Phase 10 100% master plan; §1 = spec-corpus JIT execution mode); ADR-0116
  (RTT 8-deep Cohen display + subtype check); ADR-0127 (cross-module func type-identity);
  ADR-0126 (canonical type ids); ADR-0115 §10 (non-moving β collector); ADR-0060 (force-spill).
  ROADMAP §10.
- Debt: **D-211** (GC-on-JIT — emit done; §1 verifies it), D-212 (GC FP-value marshal gap —
  surfaces under §1 mode), D-209 (stale), D-202 / D-198 / D-210. Lessons
  `2026-05-31-spec-jit-corpus-fails-are-gaps-not-stale-state` (this turn — measure the fail
  taxonomy before building the mechanism a narrative assumed) +
  `2026-05-31-jit-passthrough-result-clobbered-by-call` +
  `2026-05-31-wasmgc-jit-non-moving-deferred-rooting` +
  `2026-05-30-phase10-jit-coverage-partial-spec-corpus-interp`.
