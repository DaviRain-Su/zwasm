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
- **Cycles-remaining**: ~0 (impl DONE on Mac; awaiting ubuntu `test-all` verification → then close + §16.6 [x])
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
- **DONE (Mac green)**: ADR-0160 (`ee91686f`); **D-258** (`3bd04703`) maybeCollectJit + wired both trampolines +
  RED→GREEN gc_cycles>0 test; **D-261** (`b332081a`) adversarial survival test (held local across collect → A.field
  stays 42; UAF would slot-reuse → 0). Mac test+lint+zone green. **Residual D-276**: the callee-saved-register-
  resident worst case isn't independently forced (D-261 covers the held-local shape; zwasm's frame-spilled regalloc
  makes the common case safe). **BUNDLE CLOSE (next cycle)**: verify ubuntu `test-all` green (Step 0.7) → `bash
  scripts/check_bundle_active.sh --close` → mark §16.6 [x] → open §16.7 docs.

## NEXT (autonomous — §16.6 memory-safety → docs; ADR-0156)

- **§16.6 memory-safety — driven by the Active bundle above** (design done = ADR-0160; impl = maybeCollectJit +
  wire + D-258/D-261 tests). Resume via the bundle's NEXT IMPL steps.
- After §16.6: **§16.7** docs LAST (README/reference/tutorial/CHANGELOG, match the settled surface).
- Backlog notes (not blockers): **D-269** funcref opaque `?u64` (not callable from a table slot — deeper
  enhancement); **D-273** CLI flag parity; **D-274** zlinter eager fetch; **D-275** `Module.instantiate` coarse
  error; `examples/` not fmt-gated by `gate_commit.sh` (caught manually).

## Step 0.7 (next resume)

**Verify ubuntu `test-all`** — this turn pushed §16.6 D-258 (`3bd04703`) + D-261 (`b332081a`): wires the JIT GC
trampoline collect + the conservative-rooting survival test. Kicked `run_remote_ubuntu test-all` (D-262 — the
collect path runs the platform-specific native-stack scan, so cross-RUN on Linux x86_64 is load-bearing, not just
cross-compile). Tail `/tmp/ubuntu.log` for `OK (HEAD=…)`. On GREEN → close the bundle + mark §16.6 [x]. On FAIL →
revert the turn's commits (the rooting may not hold on x86_64 → a real D-261 finding). **Gate**: Step-5 Mac =
`bash scripts/mac_gate.sh`. windowsmini = Phase 16 completion boundary.

## Deferred / open debt

- **Memory-safety (§16.6)** — **D-258 + D-261 DONE on Mac** (collect trigger wired + adversarial survival test
  green); awaiting ubuntu `test-all`. Residual **D-276** (callee-saved-register-resident worst case not forced).
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
