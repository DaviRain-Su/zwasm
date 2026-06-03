# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — re-scoped (ADR-0133)** (Phase 9 = DONE 2026-05-24). §10 exit =
  **interp pass=fail=skip=0 (MET) + JIT 0-real-fail + every JIT skip on the forward-ref'd
  deferred-allowlist** (multi-memory-on-JIT→§14, GC-on-JIT-rooting→§11). Raw "JIT skip=0" (ADR-0128)
  was unreachable in-phase; re-scoped autonomously per ADR-0132.
- **LAST code HEAD** (`be5a1a32`): arm64 br_on_null now handles function-return/loop targets (was forward-block
  only → UnsupportedOp on br_on_null.1). Routed through the shared `op_control.branchOnReg` (pop ref → 0/1
  null-flag in a RESERVED scratch W16 — NOT the ref's reg, that clobber was a mid-fix block regression → push
  ref back). br_on_null.1 modrej cleared; function-references 23/0/16 / global 811/1 unchanged (no asserts in
  that module); no regression. **§10 JIT module-rejects cleared this session**: D-239 (precise ref.func +
  null-ref emit dispatch, `faf23f0a`) + ref_null.0 concrete ref.null const-expr (`195856a1`) + br_on_null.1.
  Built on cross-instance EH (`4f73d9ee`, ADR-0134). x86_64 br_on_null function-return parity = D-238 bucket.
- **Cross-instance EH on JIT DONE** (`4f73d9ee`, 10.E-eh-on-jit bundle CLOSED, EH dir 34/0/0; ADR-0134). x86_64
  EH thunk-parity = D-238. Built on D2 (`cb55013e`) + D3 (`16a921a8`) + Cause A (`50e5ecd3`).
- **§10-exit determination** (ADR-0133 §4): interp 100% MET + JIT 0 GENUINE fails MET (memory64 = D-234 harness,
  6 proof paths, `f507bf33`) + the 17 module-rejects are in-phase MUST-FIX (NOT deferrable; allowlist = only
  multi-memory→§14 + GC-on-JIT→§11). Remaining rejects = the Active-task list.
- **Prior**: ADR-0132/0133 (`5447cb10`, autonomous re-sequence + Phase-10 exit re-scope). interp wasm-3.0 corpus
  FULLY GREEN. Spec corpus = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`; entry = `runner.zig` `JitInstance`.
  **GATE TRAP**: corpus exe MUST be picked by mtime (`find … -exec ls -t {} + | head -1`); bare `head -1` = STALE.
- **Watch**: `runner_test.zig` ~1415 / `compile.zig` 1223 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 (WARN, < hard 2000).

## Active task — §10-exit: **clear the remaining JIT module-rejects**  **NEXT**

§10 exit (ADR-0133): interp 100% (MET) + JIT 0 genuine fails (MET — memory64 = D-234 tracked-harness, §2) +
JIT skips ⊆ deferred-allowlist. Session progress: function-references 8/0/31 → **23/0/16**; global JIT 796/1 →
**811/1**; 7 of 8 fr rejects cleared (D-239 ref.func + emit dispatch, ref_null.0, br_on_null.1). **§10.P now
reduces to EXACTLY 3 non-allowlisted JITmodrej** (everything else — multi-memory→§14, GC-rooting→§11,
eligibility-gate incl. UnsupportedEntrySignature ×7 + gc/type-subtyping `run`, D-234 memory64-harness — is
allowlisted/tracked, classified this session):
1. **`ref_is_null.0`** (concrete `(ref null $t)` table) + **`gc/i31.6`** (abstract i31ref table) — both
   ElemSegmentTypeMismatch at `compile.zig:257` → **D-240** (blocked-by): needs JIT typed/abstract-ref TABLE
   runtime (table.init from a reftype elem + table.get/set of typed refs) THEN the eql→`valTypeIsSubtype` flip
   (loosening alone SEGV'd — proven this session). Probe via `debug_jit_auto`. Multi-cycle runtime feature.
2. **`tail-call/return_call_indirect.0`** → **D-210**. NOT the obvious "op not emitted" — `emitIndirectReturnCall`
   IS wired (`op_tail_call.zig:230`) + its 3 visible gates (table_idx≠0 / results>2 / typeidx≥4096) do NOT trip
   for this module (table 0, ≤1 result, small typeidx). The UnsupportedOp is at **func[36] pc=12** =
   `return_call_indirect`-IN-`try_table` (TC×EH interaction — a terminator tail-jump inside an open try-region's
   exception-table/landing-pad bookkeeping). Next step = `debug_jit_auto` probe of func[36] to pin the exact
   UnsupportedOp site (marshalCallArgs/teardown vs the TC×try_table frame). Deep (TC+EH integration).
   **arch-pin any JitInstance regression test to arm64** (lesson this session).

Recommended next (fresh-context BUNDLE — both are deep multi-cycle features, not quick wins): **D-240** (covers 2
of 3, typed-ref table runtime) or **D-210** (TC×EH func[36], probe first). Both gate §10.P; everything else is
allowlisted/tracked. Then `scripts/check_phase10_close_invariants.sh` → flip §10.P. The broad tractable §10
work (cross-instance EH + 7 fr rejects + all classifications) is DONE this session; these 2 are the frontier.

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

THIS turn = D-210 root-cause scoping (read-only): return_call_indirect.0's UnsupportedOp is NOT the 3 visible
gates (they don't trip) — it's **func[36] = return_call_indirect-IN-try_table** (TC×EH integration), deep. So
BOTH §10.P blockers (D-210 TC×EH, D-240 typed-ref table runtime) are confirmed deep multi-cycle features. No
code; code state `2ce27d5b`, ubuntu-verified OK. NO ubuntu kick (handover-only). Next session → pick D-240 or
D-210 as a dedicated BUNDLE (Step-0 survey + debug_jit_auto probe for D-210's func[36]). The broad §10 work is
done; these 2 are the frontier.

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
