# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE 2026-05-24).
  §10 exit = official Wasm 3.0 testsuite at pass=fail=skip=0 on **both backends** (interp + JIT).
- **HEAD** (`590093f5`): **JIT catchless try_table emits** — the lowerer appends a LandingPad per
  try_table but no catch entries, so `eh_catch_entries` is null when all of a func's try_tables are
  catchless (try_table.1's `try-with-param`); both arches did `orelse UnsupportedOp`, rejecting the
  module. Coerce null→empty (catch loop over empty range = no-op). **Unblocked try_table.1 compile**:
  JIT EH dir `pass=0 fail=1 skip=33 → pass=29 fail=5 skip=0`; global assert_return `762/2/531 → 791/6/498`
  (+29 skip→pass, NO regression in other dirs). +1 unit test.
- **Prior**: `3b668110` JIT tag index space includes imported tags (validator StackTypeMismatch fix);
  `2b48dfdc`/`74d155b7` D-235 JIT call_indirect subtype. interp wasm-3.0 corpus FULLY GREEN. Spec corpus
  = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`; JIT entry = `runner.zig` `JitInstance`.
- **EH-on-JIT dispatch IS wired** (lesson `2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch`):
  throw_trampoline.zig trampolineCore + zwasmThrowTrampoline (all 3 ABIs) set eh_handler_sp/fp/pc + JMP.
  Its docstring (lines 9-35, "3c-ii deferred") is STALE — fix when next touching. With try_table.1 now
  compiling, the dispatch RUNS — and the 5 fails are real dispatch-correctness bugs (below).
- **Watch**: `runner_test.zig` 1370 / `compile.zig` 1223 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 (WARN, < hard 2000).

## Active task — `10.E-eh-on-jit` bundle: the 5 EH dispatch fails  **NEXT**

try_table.1.wasm now compiles + runs 34 asserts (29 pass). The **5 remaining JIT fails are dispatch
correctness** (two classes; likely needs `debug_jit_auto`):

1. **Catch landing-pad result/register marshalling** — `simple-throw-catch` returns `0x07a448e8`,
   `catch-complex-1` returns `0x6da8bbd8` (POINTER-like, expected i32 23/3). Caught path: a param-less
   `catch $e0 $h` brs to a void block then `(i32.const 23)` — but the result reg holds a stale exception/
   pointer. Suspect the landing-pad entry doesn't restore the value reg / spilled vregs after the trampoline
   JMP (eh_handler_sp/fp restored, but the i32-result reg = stale). NB throw-catch-param-i32 (payload case)
   PASSES — so it's the no-payload/br-to-void-block path that's wrong. START here (2 of 5).
2. **Imported-tag handling** — `catch-imported`/`imported-mismatch` return 0, `catch-imported-alias` TRAPS
   (expected i32:2/3/2). Imported tag identity at catch-match time (the tag-index-space class — imports
   shift indices; runtime tag matching for imported tags). Maybe related to #1's class for the 0s.

Find the landing-pad emit in arm64/x86_64 `end`-op handling (emit.zig ~1383-1474 patches landing_pad_pc) +
how the catch label's target receives values. Smallest red test: a void-block param-less catch returns a
constant, not a pointer.

Other non-gated tracks (after EH dispatch): **D-234** (memory64 assert_trap harness artifact),
**D-198**, **D-209**, **D-210** (return_call_indirect-in-try = func[36], a TC+EH gap). Realworld GC/EH/TC producers.

**USER-GATED (non-stop — only surface):** **§10-scope** → `.dev/phase10_scope_reassessment.md` (multi-memory's
407 JIT skips ⇒ JIT skip=0 unreachable as written; ADR-0128-amendment / user-flip). Non-gated work exists → do NOT stop.

## Active bundle

- **Bundle-ID**: `10.E-eh-on-jit` (opened `3b668110`).  **Cycles-remaining**: ~3.
- **Continuity-memo**: try_table.1.wasm per-module blocker STACK (rejects at FIRST failing func; the module
  now COMPILES + RUNS). ✅ func[6] validate StackTypeMismatch (tag index space — `3b668110`) → ✅ func[24]
  try_table emit UnsupportedOp (catchless — `590093f5`, +29 EH) → ❌ **dispatch correctness: 5 fails** (catch
  landing-pad returns pointer ×2 + imported-tag 0/trap ×3). func[36] return_call_indirect-in-try is a
  separate TC+EH gap (D-210 family). The handler dispatch is wired; the bug is value/register marshalling
  at the landing pad + imported-tag identity.
- **Exit-condition**: JIT EH dir return-fail = 0 (currently pass=29 fail=5 skip=0 → target 34/0/0).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 stale u32; D-234 (51 OOB assert_trap = harness artifact).
- **10.R** function-references — corpus green; residual = D-198 + br_on_null/cast modrej (StackTypeMismatch).
- **10.TC** tail-call — JIT matrix complete; residuals = D-210 + return_call_indirect-in-try + `wasm_of_ocaml`.
- **10.E** EH — try_table.1 compiles+runs (29/34); blocker = 5 dispatch fails above + eh_frequency runner (I20),
  c_api tag accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit COMPLETE; §1 + PHASE C + D-235 DONE; remaining = D-198 + gc_stress (I19) + dart/hoot (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

THIS turn = the catchless try_table fix (`590093f5`), chained after last turn's tag-index fix. Empirically:
EH dir pass 0→29 (skip 33→0), global 762→791 pass, NO other-dir regression (memory64 336/1, tail-call 31/0,
gc 387/0, function-references 8/0, multi-memory 0/0 all unchanged); gate green. ubuntu kick fired for
`590093f5` (verifies x86_64 build of the shared try_table.zig change). Next resume Step 0.7:
`tail -3 /tmp/ubuntu.log` — expect `OK (HEAD=590093f5)`; on FAIL investigate (x86_64 try_table emit / the
empty-slice coercion). PRIOR cycle `34ab3948` already verified OK. Mac aarch64; ubuntu = x86_64.

**Gate hygiene**: Step-5 Mac gate = `bash scripts/mac_gate.sh`. JIT corpus: `zig build test-spec-wasm-3.0-assert`
(NO bogus `-Dno-run`), freshest exe via `/usr/bin/find .zig-cache/o -name zwasm-spec-wasm-3-0-assert` (shell
`ls` alias appends `*` → exec 127), `ZWASM_SPEC_ENGINE=jit <exe> test/spec/wasm-3.0-assert --fail-detail >out 2>err`
(SPLIT stderr — emit diagnostics splice into stdout). Per-dir `JIT: return pass/fail/skip` + `JITval`/`JITfail`/`JITmodrej`.

## Key refs

- ADR-0128 (Phase 10 100%); ADR-0114 (EH design — try_table/landing pads/trampoline); ADR-0119 (naked trampoline);
  ADR-0131/0126 (subtype + canonical ids, D-235). ROADMAP §10.E. `debug_jit_auto` skill for the dispatch fails.
- Debt: **D-234**, D-198 / D-209 / D-210 / D-211 / D-212.
  Lessons: `2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch`,
  `2026-06-02-jit-corpus-late-phase-is-per-module-blocker-stacks`, `2026-06-03-jit-trampoline-mid-op-clobbers-operands`.
