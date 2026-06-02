# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — re-scoped (ADR-0133)** (Phase 9 = DONE 2026-05-24). §10 exit =
  **interp pass=fail=skip=0 (MET) + JIT 0-real-fail + every JIT skip on the forward-ref'd
  deferred-allowlist** (multi-memory-on-JIT→§14, GC-on-JIT-rooting→§11). Raw "JIT skip=0" (ADR-0128)
  was unreachable in-phase; re-scoped autonomously per ADR-0132.
- **LAST code HEAD** (`50e5ecd3`): **JIT tag-identity canon table — 10.E Cause A.** The JIT matched
  try_table catch clauses by raw local tag index, so two tag imports binding the same source tag
  (`(import "test" "e0")` ×2 → idx 0,1) compared `0==1` → no match → trap. Added `ExceptionTable.tag_canon`
  (resolves throw + catch idx to a canonical representative; null/OOB → raw-idx fallback), carried via
  `JitRuntime.tag_canon_ptr/_count` (size 448→464, layout-stable tail), built in `setup.zig` from the import
  section (same (module,name) → collapse later idx onto earlier; only when ≥2 imported tags). The JIT analog
  of interp's `*TagInstance` key (`mvp.catchTagMatches`). **EH JIT dir 31/3 → 32/2, global 793/4 → 794/3,
  skip=0** (`catch-imported-alias` passes). +1 unit test. **GATE TRAP relearned**: corpus exe MUST be picked
  by mtime (`find … -exec ls -t {} + | head -1`) — `head -1` alone returned a STALE binary and masked the
  delta as 0 until caught.
- **Prior governance turn** (`5447cb10`): ADR-0132 (cross-phase ROADMAP re-sequencing now AUTONOMOUS) +
  ADR-0133 (Phase 10 exit re-scope; close-invariant I24; §10-scope RESOLVED, USER-GATED flag retired).
  D-237 (spec-runner double-free, harness-only).
- **Prior (this bundle chain)**: `590093f5` JIT catchless try_table (eh_catch_entries null→empty; unblocked
  try_table.1 compile, +29 EH); `3b668110` JIT tag index space includes imported tags (validator
  StackTypeMismatch); `2b48dfdc`/`74d155b7` D-235 JIT call_indirect subtype. interp wasm-3.0 corpus FULLY
  GREEN. Spec corpus = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`; JIT entry = `runner.zig` `JitInstance`.
- **EH-on-JIT dispatch IS wired** (lesson `2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch`):
  throw_trampoline.zig trampolineCore + zwasmThrowTrampoline (all 3 ABIs) set eh_handler_sp/fp/pc + JMP.
  Its docstring (lines 9-35, "3c-ii deferred") is STALE — fix when next touching. With try_table.1 now
  compiling, the dispatch RUNS — the 2 remaining fails are cross-instance (Cause B / ADR-0134).
- **Watch**: `runner_test.zig` 1370 / `compile.zig` 1223 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 (WARN, < hard 2000).

## Active task — CAUSE B cross-instance EH: **cycle 1 = D3 global tag identity**  **NEXT**

try_table.1.wasm 32/34. ✅ Cause A (`50e5ecd3`). 2 remaining fails (`catch-imported`, `imported-mismatch`) are
Cause B = cross-instance throw. **Design locked in ADR-0134** (this turn) — confirmed in §10.E scope (ADR-0114
D7 + Removal cond `cross_module_throw_propagation.wat` make cross-module EH Phase-10; interp passes day-1 via
shared `*TagInstance`; ADR-0128 → JIT owes parity). The `unwind.zig:26-31` "Phase 11+" note is a STALE
impl-deferral (loses to ADR-0114; update it when D2 lands). **Two gaps** (grounded this turn):

1. **Frame unreachable** — arm64 thunk (`arm64/thunk.zig` emitThunk) DOES `STP X29,X30,[SP,#-80]!` (saves
   caller call-site LR+FP) but NEVER `MOV X29,SP`, so its frame isn't FP-linked → the FP-walk reaches the
   caller frame carrying a THUNK pc, not the caller's call-site pc → caller try_table unfindable.
2. **Single-instance dispatch** — `trampolineCore` holds one `rt`/table; must switch per-frame + compare tags
   by a GLOBAL id (Cause-A `tag_canon` is per-module local, not cross-instance comparable).

**ADR-0134 sequencing** (bundle, 3 cycles): **cycle 1 = D3** global tag identity — add a `tag_import_targets`
analog of D-225 `func_import_targets` (spec runner resolves each tag import → source global tag-id), a global
tag-id map in `JitRuntime`, throw-site + entry resolve to global id, comparison subsumes Cause-A local
`tag_canon`. Red test: cross-module throw matches by global id at the TABLE level (unit), no frame walk.
**cycle 2 = D1+D2**: thunk `MOV X29,SP` (+1 instr, both arches; bump `thunk_bytes`/asserts) + process-global
block-range→`*JitRuntime` registry + per-frame table switch in `unwind.walk`/`trampolineCore`. **cycle 3**:
x86_64 parity + `cross_module_throw_propagation.wat` fixture + 2-host. **Cycle-1 first read**: how the JIT spec
runner links modules + assigns/threads a global tag id (check `runner.zig` JitInstance link path + `setup.zig`
~266-300 func_import_targets loop = the plumbing template).

Other non-gated tracks (after EH): **D-234** (memory64 assert_trap harness artifact), **D-198**, **D-209**,
**D-210** (return_call_indirect-in-try = func[36], TC+EH gap). Realworld GC/EH/TC producers.

**§10-scope: RESOLVED** (ADR-0133, this turn) — no longer user-gated. The §10 exit is re-scoped (interp
100% + JIT 0-real-fail + JIT-skip⊆deferred-allowlist). `.dev/phase10_scope_reassessment.md` is now historical
(prep doc; superseded by ADR-0133). Future cross-phase mismatches: re-sequence autonomously per ADR-0132 (no stop).

## Active bundle

- **Bundle-ID**: `10.E-eh-on-jit` (opened `3b668110`).  **Cycles-remaining**: ~3 (Cause B = ADR-0134 D3→D1+D2→x86_64).
- **Continuity-memo**: try_table.1.wasm 32/34. ✅ func[6] validate (`3b668110`) → ✅ catchless (`590093f5`, +29)
  → ✅ result-arity (`881b25e0`, +2) → ✅ **Cause A aliased-import identity (`50e5ecd3`, +1)** → 🎯 **Cause B
  cross-instance: ADR-0134 design locked** (this turn, no code yet). NEXT = cycle 1 (D3 global tag identity).
  func[36] return_call_indirect-in-try = separate TC+EH gap (D-210 family).
- **Exit-condition**: JIT EH dir return-fail = 0 (currently pass=32 fail=2 skip=0 → target 34/0/0).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 stale u32; D-234 (51 OOB assert_trap = harness artifact).
- **10.R** function-references — corpus green; residual = D-198 + br_on_null/cast modrej (StackTypeMismatch).
- **10.TC** tail-call — JIT matrix complete; residuals = D-210 + return_call_indirect-in-try + `wasm_of_ocaml`.
- **10.E** EH — try_table.1 compiles+runs (32/34); blocker = Cause B (2 cross-instance fails) + eh_frequency runner (I20),
  c_api tag accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit COMPLETE; §1 + PHASE C + D-235 DONE; remaining = D-198 + gc_stress (I19) + dart/hoot (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

THIS turn = Cause B DESIGN only (ADR-0134 + handover; NO codegen, NO ubuntu kick — docs-only). Code state
unchanged since `73e55e6d`, ubuntu-verified OK (test-all, exit 0). Prior turn's Cause A (`50e5ecd3`) is 2-host
green. Next resume: Step 0.7 has nothing new to verify; go straight to cycle 1 (D3). Mac aarch64; ubuntu x86_64.

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
