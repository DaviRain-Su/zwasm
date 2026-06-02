# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD** (`0319d566`): §1 spec-corpus JIT mode. **D-225 cross-module imports COMPLETE** (bundle
  closed): imported-GLOBAL track (i31.3 `a6cfd65e` + i31.4 `c5ab78c1`) + FUNC track — direct-call bridge
  thunk (`e964ba6e`: `setupRuntimeLinked([]FuncImportTarget)` → ADR-0066 cohort-safe thunk arena →
  `dispatch[N]`; runner pins exporter JitInstances) + **call_indirect-of-funcref** (`0319d566`: the only
  remaining bug was the registered exporter's borrowed module bytes being freed by the importer's module
  directive → `exportedFuncTarget` re-parsed freed memory; `kept_bytes` transfers ownership. No funcref-
  specific code — `FuncEntity.funcptr`=dispatch[i] thunk, mirrored by table.set → funcptrs_buf →
  call_indirect). ref_func call-f/call-v/call-g green. Opt-in `ZWASM_SPEC_ENGINE=jit`. Mac aarch64:
  **pass=571 fail=8 skip=716** (memory64 GREEN; interp UNCHANGED, jit_mode-guarded).
  **fail taxonomy (8, deep tail)**: gc/array ×6 (corpus-context-dependent traps — array.5 `new` works
  standalone, `get` takes a ref arg), gc/type-subtyping ×1 (ADR-0127 PHASE C, user-Accept-gated),
  try_table ×1 (EH).
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

- **Bundle-ID**: `10.G-§1-gc-array-context-traps` (D-225 cross-module bundle CLOSED at `0319d566`,
  exit-condition met: ref_func green, pass=571).
- **Cycles-remaining**: ~2 (JIT-GC runtime investigation)
- **Continuity-memo**: NEXT = **gc/array ×6** (largest remaining §1 cluster). NARROWED (this cycle, via
  `--fail-detail`): the 6 fails are in the **`gc/array` manifest, modules array.5 + array.6 — F32-ELEMENT
  arrays** (type `5e 7d` = array of f32). Ops `new`/`get`/`set_get`/`len` all `JITfail err=Trap`. KEY: `new`
  is the FIRST runtime invoke after instantiate (NOT cross-directive state) — yet it traps, while the
  module DID instantiate. array.5/6 have **setup-time global-init `array.new`** (global 0 = `array.new`
  f32=1.0 ×3; global 1 = `array.new_default` ×3, via `evalGlobalInitGc`). So the dependency is the SETUP
  GC allocs, not prior asserts. RULED OUT this cycle (by reasoning): cross-directive state (`new` is FIRST
  invoke); heap OOM (heap.zig = GROW-on-demand bump alloc, offset GcRefs stable across realloc); stale-
  base-after-grow (setup allocs ~32 B = 1 page, runtime `new` ~16 B → NO grow). REMAINING: (a) `rt.gc_heap`/
  `gc_type_infos_ptr` not wired for the runtime alloc path (vs setup-time `gc_heap_typed`), or (b) an
  `array.new_default`-f32 EMIT bug. REPRO + INSTRUMENT: instantiate array.5.wasm (202 B) via
  `JitInstance.init` + invoke `"new"` (func 0 = `i32.const 3; array.new_default 0`); if it traps standalone,
  instrument the trap site — verify `rt.gc_heap`/`gc_type_infos_ptr` non-null at the jitGcAlloc trampoline
  + the array.new_default element-size/header computation for an f32-element array. Files: `setup.zig` rt
  struct (`gc_heap` / `gc_type_infos_ptr` ~805), jitGcAlloc trampoline, array.new_default emit (codegen
  `ops/wasm_3_0/array_new*`).
- **Exit-condition**: ≥1 gc/array assert flips green (array.5 `new`/`get`/`len` no longer trap).
  - **The other 2**: gc/type-subtyping ×1 = ADR-0127 PHASE C (Proposed, user-Accept-gated +
    regression-risky); try_table ×1 = EH. Skip multi-memory 51 (Phase-14).
  - **REALITY**: big levers SPENT; the tail is context-dependent (gc/array) or user-gated. Expect lower
    per-turn corpus throughput — each remaining fail is a deliberate focused investigation.

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

Prior turn ubuntu GREEN (`OK (HEAD=c0403b4e)` — the kept-bytes fix `0319d566` / ref_func +3 is remote-
verified). THIS turn = gc/array investigation only (no src change; continuity-memo narrowed to array.5/6
f32-element + setup-time global-init array.new hypothesis) → no ubuntu kick (docs-only). Next resume:
reproduce array.5 `new` standalone per the memo. Mac aarch64; ubuntu = x86_64.

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
