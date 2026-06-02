# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD** (`f1858416`): §1 spec-corpus JIT mode. Recent: D-226 reftype-param invoke (`1005d4bf` +139),
  **multi-value JIT invoke (`fad904c6`+`33b479e7`, +16) + param-bearing wrapper thunk (`f1858416`, +2) →
  762/2/531**. Multi-value: `JitInstance.invokeMulti` reuses ADR-0106's buffer-write multi-result ABI via
  `module.entry_buf` (wrapper-thunk path; NO fresh ADR, NO compileWasm change). `jitReturnEligible` admits
  results_len>1, routes scalar multi-value through invokeMulti; `JitModule.hasThunk` gates NO_THUNK → skip.
  `emitAarch64` now also emits the 1-param 2-GPR-result thunk (LDR X1,[X2] → body AAPCS slot). **JIT-EXECUTED
  fails = 2, UNCHANGED** (gc/type-subtyping = ADR-0127 PHASE C; eh/try_table = EH-on-JIT). Interp UNCHANGED.
  **D-228 (gate hole, FIXED)**: `test-all` didn't run the wasm_3_0 unit tests → chunk-2's stale eligibility
  assert false-greened; now `test_all_step.dependOn` both unit artifacts.
- **PER-MODULE blocker-STACK reality** (lesson `2026-06-02-jit-corpus-late-phase-is-per-module-
  blocker-stacks`): since memory64 (+208, last big mover), every gc/funcref fix has been correct
  but ~0 corpus — each remaining module has 3-6 DISTINCT blockers; JIT rejects at the FIRST
  (`JITmodrej`), so a module flips only when its LAST clears. Big levers are SPENT. Remaining
  reject causes: MultipleMemories 51 (Phase-14 deferred), InvalidGlobalInitExpr 9 (struct.new/
  array.new const-expr — heap alloc), UnsupportedOp 7 (any.convert_extern needs EMIT),
  StackTypeMismatch 6 (funcref br_on_null validator gap), UnsupportedEntrySignature 7, InvalidFuncIndex 4.
- **Two paths**: spec corpus = interp by default; JIT is opt-in `ZWASM_SPEC_ENGINE=jit` (default
  test-all unchanged). JIT entry = `runner.zig` `JitInstance`. ADR-0128 + ADR-0127 Accepted (no user gate).
- **Watch**: `runner_test.zig` 1264 (gc tests extracted → `runner_gc_test.zig`). Over soft 1000 WARN, under hard 2000.

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

- **Bundle-ID**: `10.G-§1-multivalue` (prior `10.G-§1-skip-reduction` CLOSED — its gap-op + invoke
  levers SPENT: `struct.get_s/u`, `array.init_*`, convert, D-226 reftype-param invoke).
- **Cycles-remaining**: ~0-1 (CLOSE-eligible). Multi-value invoke (+16) + arm64 1-param 2-result wrapper
  thunk (`f1858416`, +2) LANDED → 762/2/531. ADR-0106 (Closed) already defined the buffer-write ABI; the
  gap was only the wasm-3.0 `JitInstance` not wiring `module.entry_buf` — `invokeMulti` mirrors the 2.0 path.
- **LOW-YIELD FINDING**: the param-bearing arm64 thunk (1-param 2-result) added only **+2** (gc 384→386),
  NOT the hoped ~20 struct.10. struct.get_packed returns ONE value (already single-result eligible); the
  remaining multi-value skips need shapes the 1-param thunk doesn't cover (2/3-param, 3-result-with-param,
  FP-result, x86_64-SysV-param-bearing — SysV `emit` still rejects params, wrapper_thunk.zig:173). **Measure
  the actual multi-value skip shape distribution (instrument the NO_THUNK skip with params/results counts)
  BEFORE more hand-emitted arm64 asm** — the per-shape ROI is small and the asm risk (W54-class) is real.
- **REASSESS — likely pivot**: §1 multi-value tail is low-yield; residual skip=531 is dominated by
  multi-memory 407 (Phase-14 deferred, NOT a §10 lever). §1 JIT-corpus is at its non-deferred floor. Higher
  value: the 2 gated fails (**ADR-0127 PHASE C** closes a real JIT-executed fail) or §10 realworld producers
  (§5; `wasm_of_ocaml` / `emcc -fwasm-exceptions` / `guile-hoot`).
- **Continuity-memo**: §1 JIT-EXECUTED assert_return fails = 2 (type-subtyping ADR-0127 PHASE C; try_table
  EH) — both deep/gated. JIT corpus = **762/2/531**.
- **Exit-condition**: bundle CLOSE-eligible — §1 tractable multi-value skip-reduction is largely done (+18
  total). Either measure+extend thunk shapes (if ROI confirmed) or CLOSE and pivot to gated fails / realworld.

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

THIS turn = multi-value JIT invoke (`fad904c6`+`33b479e7`, +16) → param-bearing wrapper thunk (`f1858416`,
+2) + D-228 gate-hole fix (`7bb3699a`) → corpus 762/2/531. Mac-green (mac_gate.sh test-all + lint, NOW incl.
the wasm_3_0 unit tests per D-228; JIT corpus green; 2 fails are the known gated ones). Next resume Step 0.7:
`tail -3 /tmp/ubuntu.log` — expect `OK (HEAD=f1858416)`; on FAIL revert this turn's commits to the last
ubuntu-verified HEAD. Then REASSESS per Active bundle (likely pivot — §1 multi-value tail is low-yield;
ADR-0127 PHASE C / realworld producers are higher value). Mac aarch64; ubuntu = x86_64.

**Gate hygiene (NEW, `2134116b`)**: use `bash scripts/mac_gate.sh` for the Step-5 Mac gate —
never `zig build test-all > log; grep -c … log` (trailing `grep -c` exits 1 on zero matches →
false "command failed" notification on a green build). Inspect via `$MAC_GATE_LOG` separately.

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
