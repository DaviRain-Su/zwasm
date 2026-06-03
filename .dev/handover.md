# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — re-scoped (ADR-0133)** (Phase 9 = DONE 2026-05-24). §10 exit =
  **interp pass=fail=skip=0 (MET) + JIT 0-real-fail + every JIT skip on the forward-ref'd
  deferred-allowlist** (multi-memory-on-JIT→§14, GC-on-JIT-rooting→§11). Raw "JIT skip=0" (ADR-0128)
  was unreachable in-phase; re-scoped autonomously per ADR-0132.
- **LAST code HEAD** (`dbcfff1b`): return_call_indirect on **non-zero table index** (both arches) — the LAST
  non-allowlisted §10.P JIT modrej (`return_call_indirect.0`) CLEARED. emitIndirectReturnCall only had the
  table-0 fast path + gated `table_idx != 0`; func[36] dispatches on tables 0/1/2. Now mirrors emitCallIndirect's
  multi-table slow path. tail-call return **31→71 (+40, skip 40→0)**. The prior "TC×EH in try_table" claim was
  WRONG (func[36] has no try_table — disassembled); also mis-attributed to D-210 (which is a SEPARATE open debt:
  cross-module frame-consuming TC cohort save). **§10.P spec-corpus exit (ADR-0133 I24) now MET**: interp 100% +
  JIT 0 genuine fails (memory64 fail=1 = D-234) + all skips/modrej allowlisted (8 eligibility-gate + multi-mem→§14).
  Prior code: D-240 (`3af19c65`), br_on_null (`be5a1a32`), cross-instance EH (`4f73d9ee`).
- **Cross-instance EH on JIT DONE** (`4f73d9ee`, 10.E-eh-on-jit bundle CLOSED, EH dir 34/0/0; ADR-0134). x86_64
  EH thunk-parity = D-238. Built on D2 (`cb55013e`) + D3 (`16a921a8`) + Cause A (`50e5ecd3`).
- **§10-exit determination** (ADR-0133 §4): interp 100% MET + JIT 0 GENUINE fails MET (memory64 = D-234 harness,
  6 proof paths, `f507bf33`) + the 17 module-rejects are in-phase MUST-FIX (NOT deferrable; allowlist = only
  multi-memory→§14 + GC-on-JIT→§11). Remaining rejects = the Active-task list.
- **Prior**: ADR-0132/0133 (`5447cb10`, autonomous re-sequence + Phase-10 exit re-scope). interp wasm-3.0 corpus
  FULLY GREEN. Spec corpus = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`; entry = `runner.zig` `JitInstance`.
  **GATE TRAP**: corpus exe MUST be picked by mtime (`find … -exec ls -t {} + | head -1`); bare `head -1` = STALE.
- **Watch**: `runner_test.zig` ~1415 / `compile.zig` 1223 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 (WARN, < hard 2000).

## Active task — §10.P FORMAL CLOSE (close-eligible; run the audited close)  **NEXT**

**Phase 10 is CLOSE-ELIGIBLE.** `check_phase10_close_invariants.sh` = **16 PASS / 9 SKIP / 0 FAIL** →
"close-eligible (invariants satisfied)". The ADR-0133 spec-corpus exit (I24) is MET (`dbcfff1b`: interp 100% +
JIT 0 genuine fails, memory64 fail=1 = D-234 harness + all skips/modrej allowlisted). I18 discharged this turn:
the 14 now-debts → 0 (deleted 5 resolved: D-199/200/201/218/220; re-classified 9 deferred to blocked-by/note).

**NEXT = the formal close procedure (one focused turn):**
1. **MANDATORY `audit_scaffolding`** (phase-boundary trigger; weight §F debt-coherence — the sweep is fresh).
   block finding → fix-local-or-ADR, both continue.
2. Flip §10.P `[x]` in ROADMAP §9.10 (routine, no ADR per §18) + Phase Status widget Phase 10 → DONE.
3. Backfill §10 SHA pointers; open **Phase 11** (widget IN-PROGRESS + expand task table — first row = GC
   reclamation / rooting per ADR-0128 §2, the D-211 follow-on).
4. windowsmini phase-boundary reconciliation — per user policy autonomous loop DEFERS windowsmini + batch-
   resolves; note it deferred, don't block the close.

The 9 invariant SKIPs are close-cycle/later-phase checks (I3/I5/I11/I20/I23 run-at-close; I14→Phase 13,
I16/I24 = now-met, I21 realworld producers). Verify at the close.

Other open (all blocked-by/note now): **D-210** (cross-module TC cohort), **D-211** (GC rooting→Phase 11),
**D-238** (x86_64 EH parity), **D-234** (memory64 harness), realworld GC/EH/TC producers.

**§10-scope: RESOLVED** (ADR-0133) — autonomous. Future cross-phase mismatches: re-sequence per ADR-0132 (no stop).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 stale u32; D-234 (51 OOB assert_trap = harness artifact).
- **10.R** function-references — corpus green; JIT 36/0/3 (all 8 modrej cleared incl. ref_is_null via D-240);
  residual skips = scalar-arg eligibility gate (allowlisted) + D-198 cast modrej.
- **10.TC** tail-call — JIT 71/0/0 (multi-table return_call_indirect cleared `dbcfff1b`); residual = D-210
  (cross-module frame-consuming TC, not a corpus blocker) + `wasm_of_ocaml` realworld.
- **10.E** EH — JIT EH dir **34/0/0** (cross-instance DONE, `4f73d9ee`); residual = x86_64 parity (D-238) +
  eh_frequency runner (I20), c_api tag accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit COMPLETE; §1 + PHASE C + D-235 DONE; gc/i31.6 cleared (D-240); remaining = D-198 + gc_stress (I19) + dart/hoot (I21).
- **10.P** close — spec-corpus exit MET (`dbcfff1b`); formal flip gated on I18 debt-discharge (14 now → 0) + close audit.

## Step 0.7 (next resume)

THIS turn = I18 debt-discharge sweep (DOCS-ONLY): verified `dbcfff1b` ubuntu OK (`eba86890`), then swept the 14
now-debts → 0 (5 deleted resolved, 9 re-classified blocked-by/note). `check_phase10_close_invariants.sh` now
**16 PASS / 9 SKIP / 0 FAIL** → Phase 10 close-eligible. NO code change → NO ubuntu kick (debt.yaml/handover
only; Step 0.7 next cycle = first-resume exception, nothing to verify). Next → the audited §10.P formal close.

**Gate hygiene**: Step-5 Mac gate = `bash scripts/mac_gate.sh`. JIT corpus: `zig build test-spec-wasm-3.0-assert`
(NO bogus `-Dno-run`); **pick the exe by mtime** — `/usr/bin/find .zig-cache/o -name zwasm-spec-wasm-3-0-assert
-type f -exec ls -t {} + | head -1` (bare `head -1` returns a STALE binary → masks the delta; relearned this turn).
`ZWASM_SPEC_ENGINE=jit <exe> test/spec/wasm-3.0-assert --fail-detail >out 2>err` (SPLIT stderr). Per-dir
`JIT: return pass/fail/skip` + `JITval`/`JITfail`/`JITmodrej`.

## Key refs

- ADR-0128 (Phase 10 100%); ADR-0114 (EH design — try_table/landing pads/trampoline); ADR-0119 (naked trampoline);
  ADR-0131/0126 (subtype + canonical ids, D-235). ROADMAP §10.E. `debug_jit_auto` skill for the dispatch fails.
- Debt: **D-234**, D-198 / D-209 / **D-210** (cross-module TC cohort, open) / D-211 / D-212; I18 = 14 now-debts to sweep.
  Lessons: `2026-06-03-reprobe-blocked-by-barriers-before-scoping` (D-240 + D-210 root-cause),
  `2026-06-03-jitinstance-test-compiles-for-host-arch`, `2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch`.
