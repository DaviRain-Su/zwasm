# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — re-scoped (ADR-0133)** (Phase 9 = DONE 2026-05-24). §10 exit =
  **interp pass=fail=skip=0 (MET) + JIT 0-real-fail + every JIT skip on the forward-ref'd
  deferred-allowlist** (multi-memory-on-JIT→§14, GC-on-JIT-rooting→§11). Raw "JIT skip=0" (ADR-0128)
  was unreachable in-phase; re-scoped autonomously per ADR-0132.
- **LAST code HEAD** (`4f73d9ee`): **cross-instance EH on JIT WORKS — EH JIT dir 34/0/0 (ADR-0134, Cause B DONE).**
  A module-1 throw now reaches a module-2 catch. Three pieces (cycle 2b): (D1) arm64 bridge thunk gains
  `MOV X29,SP` after the STP so its frame FP-links into the chain (else the FP-walk reaches the caller frame
  carrying a thunk pc; instr 19→20 ate the pad, size 96 unchanged); (registration) the spec runner registers
  each heap-pinned instance's `*JitRuntime` in `eh_registry` (+ unregister at every free site + per-manifest
  reset); (handler-cmap) `trampolineCore` resolves the catching instance's `CodeMap` from `handler_abs_pc`
  (`eh_registry.codeMapForPc`) for the cross-instance SP-restore. **EH dir 32/2 → 34/0/0; global JIT 794/3 →
  796/1; no regression.** Built on D2 (`cb55013e`, unwind machinery: `lookupByIdentity` + `walk` `InstanceResolver`
  + `eh_registry`) + D3 (`16a921a8`, global `tag_ids` u64 cross-module identity) + Cause A (`50e5ecd3`).
- **10.E-eh-on-jit bundle = CLOSED** (`4f73d9ee`, exit 34/0/0 verified). x86_64 EH thunk-parity +
  `cross_module_throw_propagation.wat` fixture = **D-238** (ADR-0134 cycle 3; arch-parity, not Mac-§10-gating).
- **LAST code HEAD** (`faf23f0a`): **D-239 — JIT function-references precise ref.func typing + null-ref emit.**
  JIT `compile.zig` now passes the validator's `func_type_indices` (ADR-0123 D4 precise `ref.func`, was abstract
  funcref → StackTypeMismatch) + wired br_on_null/br_on_non_null/ref_as_non_null into BOTH arm64 + x86_64 emit
  dispatch (handler files existed, never routed). function-references 8/0/31 → 20/0/19; global JIT **796/1 →
  808/1**; 5 of 8 fr rejects cleared; no regression; +1 regression test.
- **§10-exit determination** (ADR-0133 §4): interp 100% MET + JIT 0 GENUINE fails MET (memory64 = D-234 harness,
  6 proof paths, `f507bf33`) + the 17 module-rejects are in-phase MUST-FIX (NOT deferrable; allowlist = only
  multi-memory→§14 + GC-on-JIT→§11). Remaining rejects after D-239 = the Active-task list.
- **Prior**: ADR-0132/0133 (`5447cb10`, autonomous re-sequence + Phase-10 exit re-scope). interp wasm-3.0 corpus
  FULLY GREEN. Spec corpus = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`; entry = `runner.zig` `JitInstance`.
  **GATE TRAP**: corpus exe MUST be picked by mtime (`find … -exec ls -t {} + | head -1`); bare `head -1` = STALE.
- **Watch**: `runner_test.zig` ~1415 / `compile.zig` 1223 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 (WARN, < hard 2000).

## Active task — §10-exit: **clear the remaining JIT module-rejects**  **NEXT**

§10 exit (ADR-0133 §4): interp 100% (MET) + JIT 0 genuine fails (MET — memory64 = D-234 harness) + clear the
17 module-rejects (in-phase must-fix, NOT deferrable). ✅ **D-239 DONE** (`faf23f0a`): JIT now passes the
validator's `func_type_indices` (precise `ref.func` typing) + wired br_on_null/br_on_non_null/ref_as_non_null
into both-arch emit dispatch → function-references 8/0/31 → 20/0/19 (+12), global 796/1 → **808/1**, 5 of 8 fr
rejects cleared, no regression. **Remaining rejects (NEXT, pick highest-leverage)**:
1. **tail-call** `return_call_indirect.0` UnsupportedOp (D-210) — TC emit gap (return_call_indirect not emitted).
2. **D-239 residual 3** (distinct mechanisms, tracked in D-239): `br_on_null.1` UnsupportedOp (emit handler is
   first-cut forward-block-only → needs loop/return-target path); `ref_is_null.0` ElemSegmentTypeMismatch
   (elem-segment reftype validate gap); `ref_null.0` InvalidGlobalInitExpr (const-expr ref.null typing in
   `rv.validateGlobalInitExpr`).
3. **gc** `i31.6` ElemSegmentTypeMismatch + **UnsupportedEntrySignature ×7** (invoke-path eligibility — verify
   if real rejects or the eligibility-gate skips the audit classified as on-allowlist).
4. **D-234** runner-side harness discharge (so the corpus stops false-reporting the 52 mem64 fails — needed
   for the "0-real-fail" count to read clean; codegen proven correct).

Process: each is a small TDD fix (red minimal-module via `JitInstance.init` → green → corpus delta). Verify the
`function-references` 3 residual share no hidden root before splitting effort. Run `scripts/check_phase10_close_invariants.sh`
when the reject count hits 0 to confirm §10.P can flip.

Other tracks: **D-238** (x86_64 EH parity), realworld GC/EH/TC producers.

**§10-scope: RESOLVED** (ADR-0133) — autonomous. Future cross-phase mismatches: re-sequence per ADR-0132 (no stop).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 stale u32; D-234 (51 OOB assert_trap = harness artifact).
- **10.R** function-references — corpus green; residual = D-198 + br_on_null/cast modrej (StackTypeMismatch).
- **10.TC** tail-call — JIT matrix complete; residuals = D-210 + return_call_indirect-in-try + `wasm_of_ocaml`.
- **10.E** EH — JIT EH dir **34/0/0** (cross-instance DONE, `4f73d9ee`); residual = x86_64 parity (D-238) +
  eh_frequency runner (I20), c_api tag accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit COMPLETE; §1 + PHASE C + D-235 DONE; remaining = D-198 + gc_stress (I19) + dart/hoot (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

THIS turn = cross-instance EH 2b (`4f73d9ee`, code; arm64 thunk + registration + handler-cmap). Mac `test-all` +
lint GREEN; JIT corpus EH dir 34/0/0, global 796/1, no regression. ubuntu `test-all` kicked against the turn HEAD
— Step 0.7 next resume: `tail -3 /tmp/ubuntu.log`, revert the commit pair on FAIL. NOTE: ubuntu (x86_64) runs the
interp+unit gate, NOT the JIT EH corpus (Mac-only); x86_64 EH thunk parity = D-238. (Prior 2a `5e076a6f`
ubuntu-verified OK this turn.) Then → §10-exit endgame (the 1 memory64 return-fail + skip-allowlist audit).

**Gate hygiene**: Step-5 Mac gate = `bash scripts/mac_gate.sh`. JIT corpus: `zig build test-spec-wasm-3.0-assert`
(NO bogus `-Dno-run`); **pick the exe by mtime** — `/usr/bin/find .zig-cache/o -name zwasm-spec-wasm-3-0-assert
-type f -exec ls -t {} + | head -1` (bare `head -1` returns a STALE binary → masks the delta; relearned this turn).
`ZWASM_SPEC_ENGINE=jit <exe> test/spec/wasm-3.0-assert --fail-detail >out 2>err` (SPLIT stderr). Per-dir
`JIT: return pass/fail/skip` + `JITval`/`JITfail`/`JITmodrej`.

## Key refs

- ADR-0128 (Phase 10 100%); ADR-0114 (EH design — try_table/landing pads/trampoline); ADR-0119 (naked trampoline);
  ADR-0131/0126 (subtype + canonical ids, D-235). ROADMAP §10.E. `debug_jit_auto` skill for the dispatch fails.
- Debt: **D-234**, D-198 / D-209 / D-210 / D-211 / D-212.
  Lessons: `2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch`,
  `2026-06-02-jit-corpus-late-phase-is-per-module-blocker-stacks`, `2026-06-03-jit-trampoline-mid-op-clobbers-operands`.
