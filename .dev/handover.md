# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD**: §1 spec-corpus JIT mode — gc const-expr globals through JIT (`824fa694`, D-223) +
  **gc test extraction** (`99e122e1`: runner_test.zig 1983→1180, gc tests → `runner_gc_test.zig`).
  Opt-in `ZWASM_SPEC_ENGINE=jit`. Mac aarch64: **pass=538 fail=22 skip=735** (D-223: +43, biggest
  mover since memory64; memory64 100% GREEN; interp test-all UNCHANGED — verified `b217d0c9` ubuntu).
  **fail taxonomy (22)**: gc 17 (6× f32 = **D-212**, re-scoped below; gc/array+i31 `err=Trap` = D-218)
  + function-references 4 (D-198) + try_table 1 (EH).
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

- **Bundle-ID**: `10.G-§1-jit-corpus-mode`
- **Cycles-remaining**: ~3
- **Continuity-memo**: ADR-0128 §1 — add a JIT EXECUTION path to the wasm-3.0 spec runner
  (`test/spec/spec_assert_runner_wasm_3_0.zig`): compile every fn → instantiate → invoke the
  exported fn via the JIT entry (NOT interp `instance.invoke`→`_dispatch.run`) → compare
  assert_return / assert_trap (wasmtime `tests/wast.rs` pattern). **Incremental** (the whole
  point of the should_fail list): start with the subset `runI32Export`/`callI32NoArgs` already
  supports — **no-arg i32-result exports GREEN**; track args / i64 / f32/f64 / v128 /
  multi-value / host-imports / typed-trap as a per-backend SKIP list (enumerated, NOT silently
  dropped). The general arg/result **dispatcher is a SEPARATE downstream chunk** — do NOT block
  the backbone on it. **Calling-convention 裏取り = RESOLVED** (2026-05-31, `entry.zig`
  read): JIT'd Wasm fns are invoked via the **C ABI** (`callconv(.c)`) — X0/RDI = `*JitRuntime`,
  then Wasm params in declaration order across GPR/FP banks per AAPCS64/SysV (int→X1../RSI..,
  FP→V0../XMM0..), NOT the operand stack. PROOF = the existing tested monomorphized helpers,
  esp. the mixed `callVoid_i64f32f64i32i32` family (`entry.zig:369-409`, exercises both arg
  banks) + the `entry.zig:367` comment. The dispatcher just builds the matching `callconv(.c)`
  fn-ptr per signature. Mode toggle: env `ZWASM_SPEC_ENGINE=jit` (simplest) — `build.zig:15`
  documents `-Dengine interp/jit/both` but it is NOT yet implemented.
- **Exit-condition**: ≥1 `assert_return` executes THROUGH the JIT + compares. ✓ **MET** long ago.
  Infra COMPLETE; backbone operational (pass=484). Bundle stays open as the diagnostic-driven
  gap-fixing vehicle (`JITmodrej` tally → fix biggest tractable lever).
- **NEXT chunk** = **D-212 — root cause CONFIRMED this cycle (deterministic standalone repro)**.
  `struct.get`/`array.get` of an **f32/f64 field returns a GPR-class result that never reaches V0/XMM0**
  when it feeds a function return → the f32-return reads a stale FP reg (0.0 by luck standalone, 0x69
  in-corpus). Verified: SAME `struct.7.wasm` bytes → 0.0 standalone vs 0x69 in-corpus (stale-reg
  dependence). RED TEST (write it first, fails in a clean process): `(module (type $s (struct (field
  f32))) (func $inner (param (ref $s)) (result f32) local.get 0 struct.get 0 0) (func (export "f")
  (result f32) f32.const 2.5 struct.new 0 call 0))` via `runF32Export` → expect 2.5 (full bytes in
  D-212 row). Same-frame `struct.new(2.5); struct.get; return` WORKS; only cross-func/function-return
  fails. FIX: make struct.get/array.get f32/f64 result FP-class (mirror f32.load `encLdrSReg`/movss in
  `op_memory.zig`) OR FMOV GPR→V0 in the f32-return epilogue; both arches. Needs the field valtype at
  emit (EmitCtx lacks GC type table — thread it, or use the validator's known result vreg type). See
  D-212 row. Skip multi-memory 51; AFTER D-212: gc/array+i31 `err=Trap` (D-218), ref_func 4 (D-198).

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

Prior turn (`ee41267a`, gc test split) ubuntu `test-all` = GREEN (verified: interp identical to
baseline → split behaviour-neutral). THIS turn = INVESTIGATION-ONLY (D-212 root cause confirmed via
spikes; debt+handover only, no src change → code == green `ee41267a`). SKIP Step 0.7 ubuntu next
resume (no code delta). Mac aarch64 primary; ubuntu = x86_64.

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
