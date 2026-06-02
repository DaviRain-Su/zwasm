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
- **Prior**: ADR-0132/0133 (`5447cb10`, autonomous re-sequence + Phase-10 exit re-scope). interp wasm-3.0 corpus
  FULLY GREEN. Spec corpus = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`; entry = `runner.zig` `JitInstance`.
  **GATE TRAP**: corpus exe MUST be picked by mtime (`find … -exec ls -t {} + | head -1`); bare `head -1` = STALE.
- **Watch**: `runner_test.zig` ~1415 / `compile.zig` 1223 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 (WARN, < hard 2000).

## Active task — §10-exit endgame: **JIT 0-real-fail + skip⊆deferred-allowlist**  **NEXT**

Cross-instance EH bundle CLOSED (34/0/0). §10 exit (ADR-0133) = interp 100% (MET) + **JIT 0-real-fail** +
every JIT skip on the deferred-allowlist. Current JIT (Mac corpus): `assert_return 796/1`, ~498 skip, 68
JITmodrej (all non-EH skip-class). **NEXT = drive JIT real-fails to 0**:

1. **The 1 remaining JIT return-fail**: `JITval [memory64/memory_trap64] i64.load ty=i64 got=0x6867666564000000`
   — a memory64 value-vs-trap (D-234 family: the 51 memory64 OOB-trap fails are documented likely-harness
   artifacts; codegen PROVEN correct via 5 isolated paths). **First step**: confirm whether this lone return-fail
   is the SAME persistent-`cur_jit` harness artifact (D-234) or a real value bug — read the assert + the
   `memory_trap64` module; if harness, the fix is runner-side (D-234 discharge: guarded fresh-instance / isolate
   the fixture). got=0x68676665'64000000 looks like leaked memory bytes ('hgfed…') → a partial/misaligned load.
2. **Skip-allowlist audit**: enumerate the 498 skips + 68 modrej, verify EACH is on the ADR-0133 deferred-allowlist
   (multi-memory-on-JIT→§14, GC-on-JIT-rooting→§11, cross-module eligibility-gate, unemitted-op). Any skip NOT on
   the allowlist = a §10-exit blocker to file/fix. The modrej (br_on_null/cast StackTypeMismatch = D-198;
   return_call_indirect UnsupportedOp = D-210; ElemSegmentTypeMismatch) are the candidates to classify.

Then §10 close (10.P) flips at JIT-0-real-fail + skip⊆allowlist (ADR-0128/0133). Other tracks: **D-238**
(x86_64 EH parity), **D-198/D-209/D-210** (residual modrej), realworld GC/EH/TC producers.

**§10-scope: RESOLVED** (ADR-0133) — autonomous. The §10 exit is re-scoped (interp 100% + JIT 0-real-fail +
JIT-skip⊆deferred-allowlist). Future cross-phase mismatches: re-sequence autonomously per ADR-0132 (no stop).

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
