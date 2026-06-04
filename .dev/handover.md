# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase 16 = Completion finalization (完成形) IN-PROGRESS — NOT a release march (ADR-0156).** Phases 0–15
  DONE. **The loop never tags/publishes/cuts over; release is manual user-only; no release gate exists.**
  Goal = clean design + lightweight-fast + full-featured + 100% spec across the runtime AND the surfaces
  (C/Zig/CLI), to あるべき論 + industry standards, **breaking v1 allowed, v1 full-parity NOT a goal**.
- **✅ §16.5 dogfooding DONE — full facade proven externally (c1-c6); D-272 CLOSED.** External
  `build.zig.zon` path-dep consumer (`examples/zig_dep/`). **c1 (`3bfa460a`)** found+fixed a real bug: `build.zig`
  made `core` via `b.createModule` (private) with **no `b.addModule`**, so `dep.module("zwasm")` panicked —
  `zig_host` only shared the in-repo private module, so ADR-0109's external-consumability was never exercised. Now
  `b.addModule("zwasm", …)`. **c2 (`713fe524`)** host imports (Linker/Caller/`defineFunc`; shipped `b10922d2`,
  survey wrongly read pending). **c3 (`804a7133`)** Memory. **c4 (`27b3274a`)** + **c5 (`c992899f`)** closed
  **D-272**: `Instance.global(name)`/`table(name)` facades (get/set/!Immutable; size/get/set/grow) + shared
  `value_conv.zig`. T1.14/T1.15 tests. Consumer runs clean: add=42/go=11/mem=1234/counter=42/table[1]=0xcafe sz=4.
  c6 sweep: multi-result ✓ (T1.6), Engine config honestly-empty, no CLI-only-vs-API gap. Open notes: **D-274**
  (consuming pulls the zlinter lint tool — make lazy), **D-275** (`Module.instantiate` coarse error — minor).
- **✅ §16.4 CLI surface review DONE (ADR-0159).** Surface locked at **`run` + `compile`** + `--version`/`--help`/
  `help` + unknown-subcommand error (testable `cli/dispatch.zig`); 5 dead stubs removed; §10.1/§10.2/§10.3
  reconciled to code-as-truth (`--engine` per ADR-0136). Flag-parity gap debt-tracked **D-273**.
- **✅ §16.2 C-API** (`e9367bb2`): `include/wasm.h` byte-identical to upstream; implemented all 129 missing extern
  fns → **gap 0 (293/293)** (`scripts/capi_surface_gap.sh`). Residual semantic limits honest+debt-noted: val
  `of.ref`=raw (D-269), standalone `_copy`→null (D-253-D), serialize=source-bytes (D-271). **✅ §16.1** migration
  guide (`58a483e8`). **✅ §16.3** Zig-API facade confirmed minimal/clean (no code change); D-267 reconciled
  (ADR-0025→ADR-0109); Zig Global/Table accessors = optional gap D-272.

## Active bundle

- **Bundle-ID**: 16.6-gc-on-jit-memsafety (D-258 → D-261)
- **Cycles-remaining**: ~2
- **Continuity-memo**: JIT collect = **conservative-scan-only** (`JitRuntime` has no `*Runtime`; collector
  `walkRootsImpl` does `scanNativeStackRoots` then `self.runtime orelse return` — so no-Runtime collect already
  works). SAFE because GC-on-JIT is **pure-JIT** (no interp↔JIT call bridging; ADR-0128 §22 precise rooting is
  interp-only/D-211) → every live GcRef is on the native stack at the trampoline CALL (caller-saved spilled
  pre-call; callee-saved saved in the `callconv(.c)` trampoline frame) → the conservative scan finds all. Add
  `root_scope.maybeCollectJit(heap, gti)` (mirror `maybeCollect` minus `bindRuntime`/RootScope-rt) + wire into
  `jit_abi.zig:502` (jitGcAlloc) + `:523` (jitGcAllocArray) BEFORE `object_alloc`. Force collect in tests via
  `heap.pressure_bytes`/`next_gc_at` small. Observe `heap.gc_cycles` + `MarkSweepCollector.last_stats.survivors`.
  ADR-0160 records the conservative-only root model + pure-JIT justification.
- **Exit-condition**: (D-258) a JIT GC-alloc loop under a low pressure threshold drives `heap.gc_cycles > 0`
  (test); (D-261) an adversarial test — a JIT fn holding a GcRef across a collect-forcing `struct.new`/`array.new`
  asserts the object SURVIVES (not swept) — green on Mac + `run_remote_ubuntu test-all` (D-262: trampoline is
  per-arch emit) + windowsmini at phase boundary, under ReleaseSafe.
- **Done so far (`<this-commit>`)**: ADR-0160 (design + pure-JIT justification). **Test harness**:
  `runner.JitInstance.init(alloc, &bytes)` is the richer harness (used across `runner_gc_test.zig`); the heap is
  set up by `setup.setupRuntime` (→ `RuntimeOwned`) and reachable as `JitRuntime.gc_heap` (downcast `*Heap`).
  NEXT IMPL: (1) find/add a `JitInstance` accessor to the `*Heap` (to set `pressure_bytes`/`next_gc_at` low +
  read `gc_cycles`); (2) add `root_scope.maybeCollectJit(heap, gti)` (drive collector directly: `coll.scan_native_stack=true`,
  `coll.collector().walkRoots(markCallbackJit, &coll)` + `.collect()` + `heap.noteCollected()`; new
  `markCallbackJit` casts ctx→`*MarkSweepCollector`→`markFromRoot`); (3) wire it at `jit_abi.zig:502`/`:523`
  before `object_alloc`; (4) RED→GREEN D-258 test; (5) D-261 adversarial test.

## NEXT (autonomous — §16.6 memory-safety → docs; ADR-0156)

- **§16.6 memory-safety — driven by the Active bundle above** (design done = ADR-0160; impl = maybeCollectJit +
  wire + D-258/D-261 tests). Resume via the bundle's NEXT IMPL steps.
- After §16.6: **§16.7** docs LAST (README/reference/tutorial/CHANGELOG, match the settled surface).
- Backlog notes (not blockers): **D-269** funcref opaque `?u64` (not callable from a table slot — deeper
  enhancement); **D-273** CLI flag parity; **D-274** zlinter eager fetch; **D-275** `Module.instantiate` coarse
  error; `examples/` not fmt-gated by `gate_commit.sh` (caught manually).

## Step 0.7 (next resume)

**No ubuntu kick this cycle** — this turn is doc-only (ADR-0160 + bundle/handover; no code). Last code-bearing
HEAD `d4f86450`/`c992899f` already green. Next code = the §16.6 bundle impl. **D-262 rule**: §16.6 wires the JIT
trampoline (per-arch emit) → `run_remote_ubuntu test-all` before discharge (cross-compile ≠ cross-run). **Gate**:
Step-5 Mac = `bash scripts/mac_gate.sh`. windowsmini = phase boundary.

## Deferred / open debt

- **Memory-safety (highest stakes; §16.6)** — **D-261** GC-on-JIT conservative rooting has NO adversarial test
  → latent UAF, **blocked on D-258** (JIT-trampoline GC collect trigger). Close D-258 → D-261 before 完成形.
- **Surface residuals** — **D-274** consuming zwasm transitively fetches zlinter (make lazy; §16.5). **D-273**
  CLI flag gap vs wasmtime (`--invoke` args/result-print, `--env`/`--fuel`/`--timeout`) — §16.5. **D-272** Zig
  Global/Table accessors (§16.5). **D-269** val `of.ref`=raw. **D-253** ref machinery (incl. D-253-D
  standalone-copy). **D-271** serialize=source-bytes (no AOT cache). **D-255** C-API WASI io. **D-251** WASI in AOT.
- **D-210** cohort root fix (D-142/206/210/245). **D-211** GcRootMap. **D-257** 10 lesson `Citing` backfill.
  **D-254** rust 3-OS. **D-249** win bench. **D-238** x86_64 EH thunk. **D-266/D-259** notes.

## Key refs

- ROADMAP §16 (16.1–16.4 ✅ → 16.5 dogfooding → 16.6 memory-safety → 16.7 docs; NO release gate). §1.2 (完成形
  industry-standard surfaces). ADR-0156 (endgame); **ADR-0159 (§16.4 CLI = run+compile)**; ADR-0157/0158 (C-API
  split + ref model); ADR-0109 (Zig facade); ADR-0136 (`run --engine`). `scripts/capi_surface_gap.sh` (gap=0).
