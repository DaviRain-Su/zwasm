# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — re-scoped (ADR-0133)** (Phase 9 = DONE 2026-05-24). §10 exit =
  **interp pass=fail=skip=0 (MET) + JIT 0-real-fail + every JIT skip on the forward-ref'd
  deferred-allowlist** (multi-memory-on-JIT→§14, GC-on-JIT-rooting→§11). Raw "JIT skip=0" (ADR-0128)
  was unreachable in-phase; re-scoped autonomously per ADR-0132.
- **LAST code HEAD** (`3af19c65`): D-240 CLOSED by a one-line validator flip — elem-vs-table reftype check
  `eql`→`valTypeIsSubtype` (Wasm 3.0 §3.3.3 subtyping). The old "loosening SEGVs (RUN=139)" warning was STALE
  (predated D-218 i31-elems + null-safe funcptr-derive, which already gave the runtime typed-ref table support);
  re-probed clean. `ref_is_null.0` + `gc/i31.6` go modrej→running; **JIT return pass 811→839 (+28)**, zero new
  fail (memory64 fail=1 = D-234 harness), assert_invalid 194/0 (no regression), no SEGV. Regression test added
  (both arches). Lesson: re-run a `blocked-by` probe before scoping it as a bundle (the barrier had dissolved).
  Prior code: br_on_null function-return (`be5a1a32`), cross-instance EH (`4f73d9ee`, ADR-0134).
- **Cross-instance EH on JIT DONE** (`4f73d9ee`, 10.E-eh-on-jit bundle CLOSED, EH dir 34/0/0; ADR-0134). x86_64
  EH thunk-parity = D-238. Built on D2 (`cb55013e`) + D3 (`16a921a8`) + Cause A (`50e5ecd3`).
- **§10-exit determination** (ADR-0133 §4): interp 100% MET + JIT 0 GENUINE fails MET (memory64 = D-234 harness,
  6 proof paths, `f507bf33`) + the 17 module-rejects are in-phase MUST-FIX (NOT deferrable; allowlist = only
  multi-memory→§14 + GC-on-JIT→§11). Remaining rejects = the Active-task list.
- **Prior**: ADR-0132/0133 (`5447cb10`, autonomous re-sequence + Phase-10 exit re-scope). interp wasm-3.0 corpus
  FULLY GREEN. Spec corpus = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`; entry = `runner.zig` `JitInstance`.
  **GATE TRAP**: corpus exe MUST be picked by mtime (`find … -exec ls -t {} + | head -1`); bare `head -1` = STALE.
- **Watch**: `runner_test.zig` ~1415 / `compile.zig` 1223 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 (WARN, < hard 2000).

## Active task — §10.P: **the LAST non-allowlisted JIT blocker = D-210**  **NEXT**

§10 exit (ADR-0133): interp 100% (MET) + JIT 0 genuine fails (MET — memory64 = D-234 tracked-harness, §2) +
JIT skips ⊆ deferred-allowlist. **§10.P now reduces to EXACTLY 1 non-allowlisted JITmodrej** (D-240 closed this
turn → ref_is_null.0 + gc/i31.6 cleared; everything else — multi-memory→§14, GC-rooting→§11, eligibility-gate
incl. UnsupportedEntrySignature ×7, D-234 memory64-harness — is allowlisted/tracked):

- **`tail-call/return_call_indirect.0`** → **D-210**. NOT the obvious "op not emitted" — `emitIndirectReturnCall`
  IS wired (`op_tail_call.zig:230`) + its 3 visible gates (table_idx≠0 / results>2 / typeidx≥4096) do NOT trip
  for this module. The UnsupportedOp is at **func[36] pc=12** = `return_call_indirect`-IN-`try_table` (TC×EH
  interaction — a terminator tail-jump inside an open try-region's landing-pad/exception-table bookkeeping).
  Next step = `debug_jit_auto` probe of func[36] to pin the exact UnsupportedOp site (marshalCallArgs/teardown
  vs the TC×try_table frame). Deep (TC+EH integration). **BUT** re-probe first per this session's lesson — the
  D-240 "blocked-by SEGV" barrier had silently dissolved; D-210's "func[36] UnsupportedOp" claim was last
  verified pre-`3af19c65`, so RE-RUN the JIT corpus on tail-call before assuming it still holds.
  **arch-pin any JitInstance regression test to arm64** if the fix is arm64-first.

Once D-210 clears: `scripts/check_phase10_close_invariants.sh` → flip §10.P. The broad §10 endgame
(cross-instance EH + all 8 fr rejects + D-240 + all classifications) is DONE; D-210 is the sole frontier.

Other tracks: **D-238** (x86_64 EH parity), realworld GC/EH/TC producers.

**§10-scope: RESOLVED** (ADR-0133) — autonomous. Future cross-phase mismatches: re-sequence per ADR-0132 (no stop).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 stale u32; D-234 (51 OOB assert_trap = harness artifact).
- **10.R** function-references — corpus green; JIT 36/0/3 (all 8 modrej cleared incl. ref_is_null via D-240);
  residual skips = scalar-arg eligibility gate (allowlisted) + D-198 cast modrej.
- **10.TC** tail-call — JIT matrix complete; residual = D-210 (return_call_indirect-in-try, func[36]) + `wasm_of_ocaml`.
- **10.E** EH — JIT EH dir **34/0/0** (cross-instance DONE, `4f73d9ee`); residual = x86_64 parity (D-238) +
  eh_frequency runner (I20), c_api tag accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit COMPLETE; §1 + PHASE C + D-235 DONE; gc/i31.6 cleared (D-240); remaining = D-198 + gc_stress (I19) + dart/hoot (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

THIS turn = D-240 CLOSED (`3af19c65`, CODE): re-probed the "blocked-by SEGV" barrier (Step 0.5 dissolution
check) — it had dissolved (D-218 + null-safe derive landed the runtime since), so the fix was a one-line flip
`eql`→`valTypeIsSubtype` at compile.zig + a regression test. JIT corpus re-measured under
`ZWASM_SPEC_ENGINE=jit`: return 811→839 (+28), 0 new fail, assert_invalid 194/0, no SEGV (verified Mac, full
`scripts/mac_gate.sh` green). **ubuntu kick SENT** against `3af19c65` (code chunk) — Step 0.7 next cycle MUST
`tail -3 /tmp/ubuntu.log`; RED → revert this turn's commits to `2ce27d5b`. Next → D-210 (re-probe first).

**Gate hygiene**: Step-5 Mac gate = `bash scripts/mac_gate.sh`. JIT corpus: `zig build test-spec-wasm-3.0-assert`
(NO bogus `-Dno-run`); **pick the exe by mtime** — `/usr/bin/find .zig-cache/o -name zwasm-spec-wasm-3-0-assert
-type f -exec ls -t {} + | head -1` (bare `head -1` returns a STALE binary → masks the delta; relearned this turn).
`ZWASM_SPEC_ENGINE=jit <exe> test/spec/wasm-3.0-assert --fail-detail >out 2>err` (SPLIT stderr). Per-dir
`JIT: return pass/fail/skip` + `JITval`/`JITfail`/`JITmodrej`.

## Key refs

- ADR-0128 (Phase 10 100%); ADR-0114 (EH design — try_table/landing pads/trampoline); ADR-0119 (naked trampoline);
  ADR-0131/0126 (subtype + canonical ids, D-235). ROADMAP §10.E. `debug_jit_auto` skill for the dispatch fails.
- Debt: **D-234**, D-198 / D-209 / D-210 / D-211 / D-212 (D-240 CLOSED `3af19c65`).
  Lessons: `2026-06-03-reprobe-blocked-by-barriers-before-scoping` (D-240),
  `2026-06-03-jitinstance-test-compiles-for-host-arch`, `2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch`.
