# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD**: §1 spec-corpus JIT mode — backbone (`0d9cddd7`) + no-arg i32/i64/f32/f64 + tests
  extracted to `runner_test.zig` (`84ac53ae`) + **single-arg scalar dispatch** (`dc87b072`:
  `runScalar1Export` keys (param,result)→`entry.callX_Y`, full 4×4 matrix). Opt-in
  `ZWASM_SPEC_ENGINE=jit`. Mac aarch64: **pass=82 fail=41 skip=1172** (was 54/12/1229; +28 pass).
  **fail taxonomy (clean, attributed)**: 41 = 29 `memory64/memory_grow64` (jit skips intervening
  `(invoke "grow")` actions → fresh recompile never grows → load traps; **D-214** state-replay
  gap, NOT miscompiles) + 12 pre-existing no-arg fails. `jitErrorIsUnwiredShape` classifies
  compile/setup rejects → SKIP, executed-wrong → FAIL. Default interp → test-all unchanged.
- **Two execution paths (CODE-verified)**: spec corpus runs **interp by default**
  (`instance.invoke`→`_dispatch.run`, `instance.zig:169`); the **JIT path is now wired as an
  opt-in mode** (`ZWASM_SPEC_ENGINE=jit`, backbone above). The standalone `runI32Export`
  (`src/engine/runner.zig`) is the underlying no-arg-i32 JIT e2e primitive.
- **ADR-0128 + ADR-0127 both Accepted** — no remaining user gate; loop runs autonomously.
- **Watch**: size barrier DISSOLVED — `runner.zig` 354 lines; e2e tests now in
  `src/engine/runner_test.zig` (1634, soft-WARN only; wired via `zwasm.zig` test loader).
  As single-arg-dispatch tests grow it, split per-concept (gc/eh/tc) before 2000.

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
- **Exit-condition**: ≥1 `assert_return` executes THROUGH the JIT + compares. ✓ **MET**
  (`0d9cddd7`). no-arg i32/i64/f32/f64 ✓ + single-arg scalar 4×4 ✓ (`dc87b072`). Bundle
  continues for shape growth. C-ABI 裏取り DONE (Continuity-memo).
- **NEXT chunk** = **D-214 state-replay** (now the cleanest high-value lever; +28 pass exposed
  it). The 29 grow fails come from jit mode BYPASSING intervening `(invoke)` action directives
  → fresh recompile loses `memory.grow`. Fix: in the jit_mode block, replay action `(invoke)`
  directives against a PERSISTENT per-module runtime (don't recompile per assert — compile the
  module once per `module` directive, keep its `RuntimeOwned`, route both actions and asserts
  through it). This both flips 29 fails→pass AND restores the pure RED signal. NOTE: the prior
  "state-bridge zero-yield" lesson was **no-arg-ONLY** (pure const fns); single-arg+ read mutated
  state, so it now PAYS — see lesson `2026-06-02-spec-jit-single-arg-reopens-state-bridge`.
  Lighter alternative if the persistent-runtime refactor is too big this cycle: 2-arg scalar
  dispatch (next skip class) — but it will ADD more state-dependent fails until D-214 lands, so
  prefer D-214 first. Then multi-value, v128. Secondary: multi-memory (407 skips; MultipleMemories
  → JitRuntime per-memory base, own chunk).
  Unemitted ops (br_on_null / return_call_indirect / …) tracked by D-198 / tail-call / ADR-0127 PHASE C.

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

This turn landed test-extraction (`84ac53ae`) + single-arg JIT dispatch (`dc87b072`). Mac
`test-all` + lint green. **Step 0.7 carryover**: prior turn's ubuntu kick (`2134116b`) was
NOT verified — `/tmp/ubuntu.log` was absent at this resume (machine/`/tmp` reset), so the
f32/f64 code commit `e453540c` is ubuntu-UNverified; prior verified code HEAD = `8c445488`.
This turn re-kicks ubuntu `test-all` against the new HEAD (handover commit below); verify next
`/continue`: `tail -3 /tmp/ubuntu.log`, expect `OK (HEAD=<that SHA>)`. On FAIL: revert this
turn's commits to `8c445488` (last confirmed ubuntu-green). Mac aarch64 primary; ubuntu confirms x86_64.

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
