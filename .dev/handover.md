# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD** (`6f1eeb4a`): on **ADR-0127 PHASE C** (cross-module func-import type-identity; closes the 4
  `gc/type-subtyping.{36,42,52,54}` assert_unlinkable fails, both backends). Cycle 1 DONE:
  `sections.canonicalEqualCross` (cross-`Types` iso-recursive type-def equality) + 4 unit tests, isolated/
  unwired. Prior: multi-value JIT invoke +18 → corpus **762/2/531** (DONE). full wasm-3.0 interp fail tally
  = 9 (1 return + 4 trap + 4 unlinkable); PHASE C closes the 4 unlinkable.
- **Recent fixes (detail in debt.yaml)**: **D-228** (`7bb3699a`) test-all now runs the wasm_3_0 unit tests
  (was `zig build test`-only → a stale assert false-greened both hosts). **D-229** (`a5f6b238`) param-bearing
  e2e test gated to aarch64 (x86_64 SysV thunk lacks params; low-ROI follow-on).
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

- **Bundle-ID**: `10.G-typesubtyping-PHASE-C` (prior `10.G-§1-multivalue` CLOSED — +18 → 762/2/531; §1 skip
  tail at its non-deferred floor, multi-value follow-ons low-ROI = D-229). Pivot rationale: §1 skip-reduction
  exhausted; binding §10 exit = fail=0 both backends; PHASE C is Accepted/autonomous (ADR-0128 100% directive).
- **Cycles-remaining**: ~1. BOTH predicates DONE+tested: `canonicalEqualCross` (`6f1eeb4a`, 4 tests) +
  `superReachesCross` (`d5183d4e`, 2 tests). NEXT (final) = the INTEGRATION chunk (retain exporter Types +
  thread into CrossModuleFuncEntry + run the check at linker resolve).
- **SCOPE**: PHASE C targets the **4 assert_unlinkable fails** `gc/type-subtyping.{36,42,52,54}` (NOT the
  assert_return run-Trap — separate RTT, still fail). PHASE A (structural) + B (finality) landed cyc236/239;
  PHASE C adds type-definition identity (canonical-equal OR declared-supertype-reach across two `Types`).
- **LOCKED DESIGN (NEXT = wiring chunk, linker path first)**: corpus path = `linker.zig` (defineCrossModuleFunc
  :315 → resolve :468). The existing PHASE B check (:491 `module_types.finals[typeidx] and !cmf.source_final`)
  only rejects importer-FINAL ← exporter-open; **`.36/.42/.52/.54` are the REVERSE** (importer-OPEN `$t1` ←
  exporter-FINAL `$t2`, structurally `()->()` but distinct defs) → uncaught. PHASE C #2 (per ADR Decision —
  use `canonicalEqualCross`, NOT the same-typespace single-Types hack): accept iff PHASE-A-structural AND
  (`canonicalEqualCross(importer_types, want_tidx, exporter_types, source_tidx)` OR exporter's supertype
  chain from source_tidx reaches a type canonicalEqualCross to want_tidx). Both-false → reject.
  - **INTEGRATION (next, both predicates ready)**: at resolve, accept iff PHASE-A AND
    (`canonicalEqualCross(&module_types, typeidx, &exporter_types, source_tidx)` OR
    `superReachesCross(&exporter_types, source_tidx, &module_types, typeidx)`) — replaces the PHASE B finality
    check at linker.zig:492 (PHASE C subsumes it: .35 importer-final still rejects via both-arms-false).
  - **Lifetime (two options)**: (a) at defineCrossModuleFunc decode exporter Types from source_inst module
    bytes + retain in CrossModuleFuncEntry, free at linker deinit (localized, manual free); (b) retain the
    Types `buildExportTypes` already decodes on the Instance ARENA (auto-freed) + add `typeidx` to
    ExportFuncType. (b) is cleaner (arena, no manual free) but touches instantiate+instance+ExportFuncType;
    (a) localizes to linker.zig. Pick at impl. source_typeidx = exporter funcidx→func-section→typeidx.
  - **Regression net (MUST stay green)**: 441 exact-equal imports (407 multi-mem + 34 EH → canonicalEqualCross
    true) + the `.30/M` valid imports (line 506 `import M.f2 as $t1` valid via $t2's super-chain reaching $t1
    with nested `(ref null $t1)` — needs the super-reach arm + exporter Types).
  - **Red test**: linker unit test, M2 exports final `$t2`, importer imports it as open `$t1` → expect link
    reject (currently wrongly links). Then api/instance.zig:572 + instantiate.zig:1657 = follow-up chunks.
- **Continuity-memo**: full wasm-3.0 fail tally (ubuntu interp): assert_return fail=1 + assert_trap fail=4
  + assert_unlinkable fail=4 = 9 (both backends share linking/validation fails). PHASE C closes the 4
  unlinkable. JIT corpus = **762/2/531**. See D-202 (PHASE A/B landed, C scope).
- **Exit-condition**: `gc/type-subtyping.{36,42,52,54}` assert_unlinkable PASS (fail 4→0 both backends), NO
  regression in the 441 exact-equal cross-module imports (407 multi-mem + 34 EH — canonically equal, must
  still link). Risk: PHASE C NARROWS acceptance; the green cross-module corpus is the net.

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

THIS turn = ADR-0127 PHASE C cycle 3: `sections.superReachesCross` predicate + 2 tests (`d5183d4e`),
isolated/unwired. BOTH predicates now ready. Mac-green (mac_gate test-all + lint). Next resume Step 0.7:
`tail -3 /tmp/ubuntu.log` — expect `OK (HEAD=d5183d4e)`; on FAIL revert to last verified HEAD (11c553a6).
Then do the INTEGRATION chunk (the final PHASE C piece) per the Active-bundle INTEGRATION note: red test
(M2 exports final `$t2`, importer imports as open `$t1` → link must reject), then retain exporter Types +
run `canonicalEqualCross`/`superReachesCross` at linker resolve, verify the 441-import regression net. Mac aarch64; ubuntu = x86_64.

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
