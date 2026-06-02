# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD** (`1005d4bf`): §1 spec-corpus JIT mode. Recent: array.init (`a11b1699` +28), convert emit
  (`b70e2604`), **D-226 reftype-param JIT invoke (`1005d4bf`, +139 — biggest since memory64)**. D-226:
  `runner.paramScalarKey` maps a `.ref` param to the i64 carrier (u64 GPR passthrough, untruncated via
  callVoid_i64) + `scalarArgBits` packs externref/funcref args → `(invoke "init" (ref.extern 0))` now runs
  under JIT → gc/ref_test|ref_cast|br_on_cast tables populate → their asserts execute + PASS. Mac aarch64 JIT:
  **assert_return pass=744 fail=2 skip=549** (was 605/2/688). **JIT-EXECUTED fails = 2, UNCHANGED**
  (gc/type-subtyping run-Trap = ADR-0127 PHASE C; eh/try_table = EH-on-JIT; --fail-detail verified no new
  fails). Interp UNCHANGED. The convert+RTT 4-cycle investigation is CLOSED: the prior "+59 regression" was
  purely the un-invokable externref-param setup, not convert/ref.test (both proven correct).
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

- **Bundle-ID**: `10.G-§1-skip-reduction` (prior gc/array bundle CLOSED at `fa596f08`, exit met: array.8
  green, pass=577; JIT-executed fails now 2, both gated/deep).
- **Cycles-remaining**: ~1 — array.init (`a11b1699` +28), convert (`b70e2604`), **D-226 (`1005d4bf` +139)** all
  DONE. The eligible gap-op + invoke-enablement §1 levers are SPENT. Bundle CLOSE-eligible; next = multi-value.
- **SPENT levers**: `struct.get_s/u` (`568ac652`), `array.init_data/elem` (`a11b1699`),
  `any.convert_extern`/`extern.convert_any` (`b70e2604`), reftype-param JIT invoke / D-226 (`1005d4bf`).
- **convert+RTT CLOSED (4-cycle investigation, +139 net)**: convert emit was correct all along; the "+59
  regression" was purely the un-invokable externref-param setup (D-226). D-226 landed +139 (744/2/549),
  biggest mover since memory64. ref.test/ref.cast/br_on_cast on the now-populated tables (incl. convert'd-
  extern at `$ta[6,7]`) all PASS — H1 (extern bounds-guard) was correct: `readObjKindHeap` returns null for
  the `0x7000…` host-ref → ref.test classifies it correctly.
- **NEXT LEVER = (b) multi-value / `buffer_write` ABI** (D-094/D-164; compileWasm hardcodes register_write,
  compile.zig:1058). ADR-grade, HIGH blast radius → file the ADR FIRST (§18.2). Would flip struct.10's ~20
  get_packed asserts + ~19 other results=2 eligibility-skips. After multi-value, the residual §1 skip=549 is
  DOMINATED by multi-memory 407 (Phase-14 deferred, NOT a §10 lever) + scattered args/v128/cross-module
  eligibility skips — i.e. §1 JIT-corpus is approaching its non-deferred floor. Reassess scope next cycle:
  multi-value ADR, or pivot to §10 realworld producers (§5) / the 2 gated fails (ADR-0127 PHASE C, EH).
- **Continuity-memo**: §1 JIT-EXECUTED assert_return fails = 2 (type-subtyping user-gated ADR-0127 PHASE C;
  try_table EH-on-JIT) — both deep/gated. JIT corpus = **744/2/549**. 2 pre-existing array_init trap_fails =
  separate assert_trap follow-on, low ROI.
- **Exit-condition**: multi-value ABI lands (post-ADR) → struct.10 ~20 + ~19 results=2 asserts flip skip→pass
  (net assert_return fail unchanged at 2). Else bundle CLOSES — §1 tractable skip-reduction is exhausted.

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

THIS turn = D-226 reftype-param JIT invoke (`1005d4bf`, code) → +139 corpus (744/2/549), Mac-green
(zig build test + lint + corpus all green; the 2 fails are the known gated ones). **STOPPED at user request
(きりが良いところ)** — loop NOT re-armed this turn. ubuntu kick fired for cross-host confirm. Next resume
Step 0.7: `tail -3 /tmp/ubuntu.log` — expect `OK (HEAD=<handover-SHA>)`; on FAIL revert. Then start the
NEXT LEVER (multi-value ABI — file ADR first) or reassess (§1 tractable skip-reduction is largely exhausted;
residual skip=549 ≈ multi-memory 407 deferred + multi-value ~39 + scattered eligibility). Mac aarch64; ubuntu = x86_64.

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
