# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — re-scoped (ADR-0133)** (Phase 9 = DONE 2026-05-24). §10 exit =
  **interp pass=fail=skip=0 (MET) + JIT 0-real-fail + every JIT skip on the forward-ref'd
  deferred-allowlist** (multi-memory-on-JIT→§14, GC-on-JIT-rooting→§11). Raw "JIT skip=0" (ADR-0128)
  was unreachable in-phase; re-scoped autonomously per ADR-0132.
- **LAST code HEAD** (`16a921a8`): **JIT global tag identity — cross-module (ADR-0134 D3, cycle 1).**
  Replaced the per-module-local `tag_canon` (u32 repr idx) with a globally-comparable `tag_ids` (u64) — the
  JIT analog of interp's `*TagInstance` key (ADR-0114 D7). `setup` builds `tag_ids` over the full tag space
  whenever the module has ≥1 tag: defined tag's id = address of its own `tag_tokens` cell (unique/instance);
  imported tag inherits the EXPORTER's id (`tag_import_targets`) else its (module,name) local rep token.
  Added `TagImportTarget` + `exportedTagTarget` + non-filtering `sections.findExportedTagIndex` (decodeExports
  drops kind=4); `initLinked` += `tag_import_targets`; spec runner `jitResolveTagImports`. Decodes imports on
  section-presence (not `num_imports`, func-only). Observable: runner_test links 2 instances, importer's aliased
  tags inherit exporter id. EH JIT dir 32/2 (Cause A green via REAL identity now), global 794/3, no regression.
- **Cause A** (`50e5ecd3`): the within-module-aliased-import fix, now subsumed by D3's global identity.
- **Prior governance** (`5447cb10`): ADR-0132 (autonomous ROADMAP re-sequencing) + ADR-0133 (Phase 10 exit
  re-scope; I24; §10-scope RESOLVED). D-237 (spec-runner double-free, harness-only). **GATE TRAP**: corpus exe
  MUST be picked by mtime (`find … -exec ls -t {} + | head -1`); bare `head -1` returns a STALE binary.
- **Prior (this bundle chain)**: `590093f5` JIT catchless try_table (eh_catch_entries null→empty; unblocked
  try_table.1 compile, +29 EH); `3b668110` JIT tag index space includes imported tags (validator
  StackTypeMismatch); `2b48dfdc`/`74d155b7` D-235 JIT call_indirect subtype. interp wasm-3.0 corpus FULLY
  GREEN. Spec corpus = interp default; JIT opt-in `ZWASM_SPEC_ENGINE=jit`; JIT entry = `runner.zig` `JitInstance`.
- **EH-on-JIT dispatch IS wired** (lesson `2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch`):
  throw_trampoline.zig trampolineCore + zwasmThrowTrampoline (all 3 ABIs) set eh_handler_sp/fp/pc + JMP.
  Its docstring (lines 9-35, "3c-ii deferred") is STALE — fix when next touching. With try_table.1 now
  compiling, the dispatch RUNS — the 2 remaining fails are cross-instance (Cause B / ADR-0134).
- **Watch**: `runner_test.zig` 1370 / `compile.zig` 1223 / `runner_gc_test.zig` 1476 / `jit_abi.zig` 1350 (WARN, < hard 2000).

## Active task — CAUSE B cross-instance EH: **cycle 2 = D1+D2 (thunk frame-link + per-frame dispatch)**  **NEXT**

try_table.1.wasm 32/34. ✅ Cause A (`50e5ecd3`). ✅ **D3 global tag identity** (`16a921a8`): a module-1 throw's
tag and a module-2 catch's imported tag now resolve to the SAME `tag_ids` u64 (verified at the table/runner
level). The 2 remaining fails (`catch-imported`, `imported-mismatch`) still fail because the UNWINDER is
single-instance: `trampolineCore` holds the throwing instance's (module 1's) `rt`/table and walks every frame
against it, so it never consults module 2's table where the catch lives. **Two gaps to close (ADR-0134 D1+D2)**:

1. **D1 — frame unreachable.** arm64 thunk (`arm64/thunk.zig` emitThunk, 96B) does `STP X29,X30,[SP,#-80]!`
   (saves caller call-site LR+FP) but NEVER `MOV X29,SP`, so its frame isn't FP-linked → the FP-walk reaches
   the caller frame carrying a THUNK pc, not the caller's call-site pc → caller try_table unfindable. Add
   `MOV X29,SP` after the STP (bump `thunk_bytes` 96→100 + size asserts; x86_64 mirror in cycle 3).
2. **D2 — per-frame dispatch.** Build a process-global block-range→`*JitRuntime` registry; the walker resolves
   each frame's abs pc → owning instance and switches the active table + `tag_ids` to it (`unwind.walk` +
   `trampolineCore`). A thunk-arena pc = pass-through frame (no try_table). Then the throw's `tag_ids`-resolved
   id (D3) matches the catch entry's `tag_ids`-resolved id in module 2's table. **Update the STALE
   `unwind.zig:26-31` "Phase 11+" comment** to describe the implemented dispatch.

Loci: `arm64/thunk.zig`/`x86_64/thunk.zig` (frame-link), `unwind.zig` walk + FrameLink, `throw_trampoline.zig`
trampolineCore (single rt today), a new registry (setup/runner link path registers each instance's block range).
**Cycle-2 first read**: the FP-walk frame loader in `throw_trampoline.zig` (how it materializes FrameLink from
the live stack) + the thunk frame layout (where caller_rt is recoverable = `[thunk_fp+16]` saved X19).

Other non-gated tracks (after EH): **D-234** (memory64 assert_trap harness artifact), **D-198**, **D-209**,
**D-210** (return_call_indirect-in-try = func[36], TC+EH gap). Realworld GC/EH/TC producers.

**§10-scope: RESOLVED** (ADR-0133, this turn) — no longer user-gated. The §10 exit is re-scoped (interp
100% + JIT 0-real-fail + JIT-skip⊆deferred-allowlist). `.dev/phase10_scope_reassessment.md` is now historical
(prep doc; superseded by ADR-0133). Future cross-phase mismatches: re-sequence autonomously per ADR-0132 (no stop).

## Active bundle

- **Bundle-ID**: `10.E-eh-on-jit` (opened `3b668110`).  **Cycles-remaining**: ~2 (ADR-0134 D1+D2 → x86_64+fixture).
- **Continuity-memo**: try_table.1.wasm 32/34. ✅ catchless (`590093f5`) → ✅ result-arity (`881b25e0`) →
  ✅ Cause A (`50e5ecd3`) → ✅ **D3 global tag identity (`16a921a8`)**: throw/catch resolve to the same `tag_ids`
  u64 across instances (table/runner-verified). 🎯 NEXT = **cycle 2 (D1+D2)**: thunk `MOV X29,SP` frame-link +
  per-frame-instance table switch so the unwinder consults module 2's table. func[36] return_call_indirect-in-try
  = separate TC+EH gap (D-210 family).
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

THIS turn = D3 cycle 1 (`16a921a8`, code). Mac `test-all` + lint GREEN; JIT corpus re-verified (EH 32/2, global
794/3, no regression). ubuntu `test-all` kicked against the turn HEAD — Step 0.7 next resume: `tail -3
/tmp/ubuntu.log`, revert the commit pair on FAIL. Mac aarch64; ubuntu x86_64. Then → cycle 2 (D1+D2).

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
