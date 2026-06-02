# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD** (`a11b1699`): §1 spec-corpus JIT mode. THIS turn: **array.init_data/init_elem JIT emit** (A-11) —
  2 trampolines jitGcArrayInit{Data,Elem} (mirror jitGcArrayFill 6-arg-CALL) + per-arch emit; init_data reads
  typeidx from ObjectHeader.info (mark-bit masked — won't fit the 6-arg SysV budget), init_elem needs none
  (esz=8 uniform). R15-whitelisted, lint clean, both backends. Mac aarch64 JIT: **assert_return pass=605
  fail=2 skip=688** (was 577/2/716 → **+28 pass, fail FLAT, −28 skip**; interp UNCHANGED). gc/array_init_data
  + gc/array_init_elem flip modrej→compile, return asserts PASS (return_fail=0); the trap_fail=1 each is
  PRE-EXISTING (verified vs stash baseline: identical) — separate interp/setup gap, NOT this emit.
  **JIT-EXECUTED assert_return fails = 2** (gc/type-subtyping = ADR-0127 PHASE C user-gated; try_table =
  EH-on-JIT). **Eligible single-result gap-ops now SPENT** (struct.get_s/u + array.init_data/elem done);
  remaining levers = RTT-entangled convert OR major multi-value/buffer_write ABI (Active bundle).
- **PER-MODULE blocker-STACK reality** (lesson `2026-06-02-jit-corpus-late-phase-is-per-module-
  blocker-stacks`): since memory64 (+208, last big mover), every gc/funcref fix has been correct
  but ~0 corpus — each remaining module has 3-6 DISTINCT blockers; JIT rejects at the FIRST
  (`JITmodrej`), so a module flips only when its LAST clears. Big levers are SPENT. Remaining
  reject causes: MultipleMemories 51 (Phase-14 deferred), InvalidGlobalInitExpr 9 (struct.new/
  array.new const-expr — heap alloc), UnsupportedOp 7 (any.convert_extern needs EMIT),
  StackTypeMismatch 6 (funcref br_on_null validator gap), UnsupportedEntrySignature 7, InvalidFuncIndex 4.
- **Two paths**: spec corpus = interp by default; JIT is opt-in `ZWASM_SPEC_ENGINE=jit` (default
  test-all unchanged). JIT entry = `runner.zig` `JitInstance`. ADR-0128 + ADR-0127 Accepted (no user gate).
- **Watch**: `runner_test.zig` 1180 (gc tests extracted → `runner_gc_test.zig`, `99e122e1`). Headroom OK.

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

- **Bundle-ID**: `10.G-§1-skip-reduction` (prior gc/array bundle CLOSED at `fa596f08`, exit met: array.8
  green, pass=577; JIT-executed fails now 2, both gated/deep).
- **Cycles-remaining**: ~2 — array.init DONE (`a11b1699`, +28); convert+RTT now the active multi-cycle sub-target.
- **Eligible single-result gap-ops SPENT**: `struct.get_s/u` (`568ac652`), `array.init_data/elem` (`a11b1699`).
- **ACTIVE sub-target = convert+RTT** (lever a). Cycle-1: convert emit (transparent `0→0` liveness + no-op
  switch arms; null round-trip green) MEASURED +80 pass / **+59 fail** in gc → reverted to spike. Cycle-2
  (this turn): DIAGNOSIS UNBLOCKED + taxonomy classified. The "diagnostic gap" was just stderr emit-noise
  splicing stdout under `2>&1` — recipe = direct exe `--fail-detail 2>/dev/null` (lesson
  `2026-06-02-jit-corpus-fail-detail-needs-stderr-split`; the runner flush + build.zig forwarding I tried were
  UNNECESSARY → reverted). **60 gc fails = ref_test ×32, br_on_cast ×10, br_on_cast_fail ×10, ref_cast ×7**
  (+1 pre-existing type-subtyping trap) — the RTT-test family. got: ref_test_i31/struct/eq/any → clean `1`
  (too-lax); ref_test_null_data → `2`; br_on_cast → `0xffffffff` (wrong branch). **H1/H3 (extern bounds-guard)
  REFUTED** — fails span i31/struct/array, not extern. **TWO live hypotheses** (`fail-taxonomy.txt` + spike
  README): **HA** = RTT-logic gap in `jitGcRefTest`/`gcAbstractMatch` for the full heap-type matrix these
  convert-unblocked comprehensive modules exercise (clean-wrong 0/1 supports); **HB** = the `0→0` transparent
  convert corrupts regalloc → garbage downstream (`got=2` supports). **NEXT-CYCLE**: distinguish HA/HB cheaply
  — HB probe = re-model convert `1→1` (real dest vreg + MOV, mirror ref.as_non_null) and re-measure (if +59
  drops → HB); HA = read `gc/ref_test.wast` expected-vs-got + audit gcAbstractMatch arms vs spec §4.5.2. If
  neither converges in 1 cycle → PIVOT.
- **PIVOT option** = lever (b) MAJOR multi-value/`buffer_write` ABI (D-094/D-164; compile.zig:1058 hardcodes
  register_write; ~39 skips; ADR-grade, HIGH blast radius) — if convert+RTT proves too deep (now 2 cycles in).
- **Continuity-memo**: §1 JIT-EXECUTED assert_return fails = 2 (type-subtyping user-gated ADR-0127 PHASE C;
  try_table EH-on-JIT). Remaining §10 exit bulk = **skip=688** (baseline, post-revert). 2 pre-existing
  array_init trap_fails (baseline-verified) = separate assert_trap follow-on, low ROI.
- **Exit-condition**: convert+RTT lands ≥1 gc module flipping modrej→compiles AND its ref.test/cast asserts
  PASS (net assert_return fail unchanged at 2).

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

THIS turn = convert+RTT DIAGNOSIS cycle-2 (no src commit; all probes reverted to clean tree; docs/lesson-only
commit). HEAD code-equivalent to `95f618e3` (ubuntu-GREEN, no code change → no ubuntu kick). Next resume: go
straight to Active-bundle convert+RTT — distinguish HA (RTT-logic) vs HB (convert 1→1 regalloc) per the plan;
re-apply `private/spikes/convert-extern-rtt/convert-emit.diff` to reproduce. Mac aarch64; ubuntu = x86_64.

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
