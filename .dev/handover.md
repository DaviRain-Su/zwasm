# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state — Phase 17 完成形 completion-refinement (release = USER-ONLY, ADR-0156)

Project at the **完成形 plateau** (all dims confirmed): clean (C/Zig/CLI audits), full-featured (WASI complete +
now cross-component STRING composition, D-305 milestone), 100% spec (`test-spec` 25539/0), lightweight-yet-fast
(v1-JIT parity, D-265 closed). Robustness: interp+JIT fuzz 0 crashes. Closed-arc detail lives in git/ADRs/lessons.

**D-305 cross-component linker — COMMON shapes ALL DONE + 3-host/x86_64-verified** (ADR-0196; detail in the
D-305 debt row + git): string/list params (@689040e6), string result (@184b5e05), `(string)->string` (@2b9b14ee),
boundary error-trap (@30bd1881, SECURITY — marshalling failures now TRAP, not silent-wrong). component_model
163/0; ubuntu OK @dfdcfdcf. Remaining rare shapes (record/result aggregates, >2-param arities) = consumer-gated
debt, do NOT grind speculatively.

**ADR-0195 guest↔guest async (multi-task scheduler) — FUNCTIONALLY COMPLETE 2026-06-17** (the D-335 last
functional gap; campaign closed-arc below). Cross-component async now works end-to-end: multi-task scheduler
(`driveScheduler`) → cross-component ROUTING (c-2b) → `task.return` capture + result round-trip (d-a/d-b-1) →
future rendezvous (d-b-2) → synchronous + BLOCKING multi-element stream rendezvous + pollSet/waitable-set delivery
+ AsyncDeadlock guard (d-c-1/d-c-2, @a82b4f84). Local gate green (test-all unit + comp-spec 163/0 + lint +
fallback). **D-463 cross-component async handle isolation CLOSED 2026-06-18 (@633189454, ADR-0197 ownership
ledger)**: a child can no longer reach a peer's un-granted stream/future end (adversarial isolation fixture
RED→GREEN). **Residual (debt-tracked, NOT blocking, do NOT grind): D-464** (broader (e) adversarial dropped/
cancelled cross-component cases + cancel-op/waitable wait-poll-drop graph builtins).

**Prior arcs**: wasi:random COMPLETE; ADR-0193 feature-separation + version SSOT; D-335 typed marshalling DONE;
C-API @b4d75506 (Windows export fix); interp+JIT fuzz 808 mods 0 crashes. ADR-0193 (D-462) + D-461 (ADR-0194)
CLOSED (below). **windowsmini RESUMED**. Version `2.0.0-alpha.3`.

## ADR-0195 guest↔guest async — CAMPAIGN COMPLETE 2026-06-17 (bundle closed; residuals = D-464/D-463)

The multi-task async scheduler closed the D-335 last functional gap. Pipeline + key SHAs (all main-loop-verified;
detail in git/commits + ADR-0195): **II(a)** char net @529cfcba · **(b)** `TaskTable`/`seedTask`/`foldResult`
@b90cbecb+@61c4a20d · **(c-1)** Zone-1 `driveScheduler` (round-robin + `pollSet` seam + all-waiting→`AsyncDeadlock`)
@822d30d5 · **(c-2a)** P3 runner unified on `driveScheduler`, retired `driveCallbackLoop` @54a9b0bc+@c7710cda ·
**(c-2b)** cross-component ROUTING (`ComponentGraph.driveAsyncMain` + `GraphAsync.callbacks` funcidx→(instance,cb)
+ `installAsyncBoundary` mints `Subtask`+enqueues `TaskDescriptor`) @a0e2d4c7a · **(d-a)** `task.return` capture
into per-task `TaskDescriptor.result` @cc63edd9 · **(d-b-1)** A consumes result via `retptr` @7cf62e3a · **(d-b-2)**
future rendezvous @4a344503 · **(d-c-1)** synchronous multi-element stream rendezvous @9eabb709 · **(d-c-2)** BLOCKING
stream rendezvous + `pollSet`/waitable-set delivery + AsyncDeadlock guard @a82b4f84. All over ONE graph-level
`GraphAsync` (shared `SharedTable`/`StreamFutureTable`/`WaitableSetTable`; `graphFuture*`/`graphStream*`/
`graphWaitable*` builtins via `pourSyntheticExport`). Fixtures `test/component/two_async_components_*.wat`
(future/stream/blocking/deadlock; assert taskResult==42). Local gate green; **3-host through @4ed08f57d** (d-c-1
batch ubuntu+win OK); **d-c-2 ubuntu OK @4f95129a** (Mac+ubuntu verified); windows BATCHED (3/12 since baseline
@4ed08f57d → verifies @a82b4f84 next fire; non-ABI, non-urgent). **Phase V retro DONE @f799128a** (ADR-0195
Status→Implemented + retrospective section; D-464 item (4) closed).

## RESUME POINTER (2026-06-18) — for a fresh session

1. **No active bundle.** At the **完成形 plateau** (ADR-0156). **Cross-component async drop/park robustness arc
   COMPLETE** — 4 real bugs found+fixed this session via adversarial tests: D-463 handle-isolation leak (ADR-0197),
   stream peer-drop hang @27f9464e0, future-drop-before-write missing trap @360382c33 (D-465, `dropEndGuarded`
   unifies graph+p2), parked-peer-drop deadlock @cc25647df (both reader+writer dirs, @34aad9314). All 3-host green
   (ubuntu+win @0e1fca6e7 recorded). 9 adversarial fixtures in `component_async_tests.zig`.
2. **Audit DONE 2026-06-18 (CLEAN)** — `audit_scaffolding` 0 block/0 soon (only J.3 chronic debt=61);
   `private/audit-2026-06-18.md`. Fuzz smoke 0 crashes.
3. **D-460 v128-GC JIT emit — get/set/new/new_fixed DONE BOTH arches** (@3d8be3c00 x86_64 struct/array mirror +
   @8137c7268 array_new_fixed both arches). arm64 had struct/array get/set/new (f79a3ced/41015a9b); x86_64 now
   mirrors via MOVUPS + running-sum struct offset + new `encShlRImm8` index×16 stride; array_new_fixed adds the
   16-byte stride/STR-Q arm. 4 runI32Export fixtures use a `v128.load` producer (struct.new/array.new_* force-spill
   the operand [ADR-0060] + x86_64 replace_lane not spilled-dst aware → would mask the GC op). Both arches GREEN
   (arm64 2954/2966, Rosetta 2960/2972). **REMAINING D-460 = array_copy ONLY** (trampoline `jitGcArrayCopy`
   per-element byte-copy must use v128 elem size — exotic, gc/array-copy-inline.6). Then D-460 closes.
4. **D-461 x86_64 v128 spill — 4 op families DONE** (extend @83256d210 3-host, Extadd @4b839f29a, splat/zero
   @612a1b6b9, **load_lane @5785dffa2 — ubuntu+win BOTH exit-0 this session**). Remaining = **replace_lane ONLY**
   (entangled with D-034 GPR-scalar; do WITH that cohort). **Remote**: load_lane 3-host GREEN. ubuntunote nix-disk
   FIXED 2026-06-18 (402GB `.zig-cache` → `rm -rf`; lesson `2026-06-18-remote-zig-cache-fills-disk-*`: "nix dep
   failed" → check `df -h`). Do NOT grind consumer-gated (D-464(2), D-305).

## Recently closed arcs (detail in ADRs/git/debt — one-liners)

- **D-305 first milestone** (@4cceeb1e, ADR-0196): cross-component STRING marshalling; `component_graph.zig`
  two-level instantiation + boundary trampoline via `canon.CanonContext`. Common shapes now ALL done (see top).
- **D-461 regalloc-origin rework** (ADR-0194, @3cd2ede6, CLOSED Phase I-V): x86_64 v128-spill OOB fixed by
  threading per-arch `max_reg_slots_gpr` into `computeSpillOffsets`; arm64 2922 + x86_64-Rosetta green. Result-write
  remainder (Extend/Extadd/replace_lane/binop-dsts, x86_64, EXOTIC) = D-461 debt row.

## Closed/paused (detail in git + debt.yaml)

- **doc-inventory freshening DONE** (`42441634` README + ADR-0193 P4 doc-sync): reader-facing surfaces clean
  (C-API 293/293, component 158/0/0, Wasm 2.0 skip-impl==0, 3.0 all-9-proposals, version anchors retired).
- **ADR-0192 wasmtime differential campaign — paused**: goal met (9 real engine bugs fixed via wasmtime
  misc_testsuite + 6 SIMD via D-457). Residuals: **`D-460`** v128-GC (arm64 struct/array get/set EMIT DONE
  `f79a3ced`/`41015a9b`; array.new_fixed/copy + x86_64 mirror unblocked NOW by the D-461 spill fixes in progress),
  **`D-209`** memory64 >4 GiB offset, **D-456** host-import fixtures (parked). Harness `scripts/wasmtime_misc_*.sh`.

**Closed campaigns (detail in git/lessons)**: prior 4-front async-maturity (2026-06-16) — ② wasmtime async .wast
TIER-1 (`afcf889a`/`05b35c28`; D-446/447 deferred), ① wasip3 conformance (7 real-rust fixtures, `.#gen-wasip3`),
④ perf (ROI-rejected single-pass ceiling, D-450), ③ real-world GC corpus (6 engine bugs FIXED: D-451-453/9064faa5/
480809af/9ec68a75/79742cb4; 4 GC edge fixtures; real Hoot execution → D-454). **WASI 0.3/Preview-3 core DONE**
(D-335; ADR-0187-0191). validator.zig at 3449/3450 cap — NEXT validator edit MUST extract per the file's marker plan.

## Long-tail (debt-tracked / parked — NOT active; see debt.yaml)

- **JIT-correctness** (front B / parked): D-330 c_sha256 `\n` (parked — conflicting-constraint; do NOT re-run the
  blanket fix) · D-331(A) go runtime-corruption (infra-blocked) · D-331(B)/D-289 go_regex emit (parked) · D-333
  (br_table, folds into D-330). Realworld corpus interp-green; JIT run-stage opt-in (`ZWASM_JIT_RUN=1`). Trace:
  `ZWASM_DEBUG=jit.dump` + `scripts/jit_value_trace.sh` (Recipe 18).
- **D-454** (future-bucket): real GC-language program execution fixture, blocked on Hoot reflect-ABI host port.

## State (all 3-host green @046d9c67/win @886d0667; release = USER-ONLY, ADR-0156)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip (GC 362/0). **WASI 0.1** complete; **0.2/CM** default-ON (corpus 158/0/0);
  **0.3 core** done. Sandboxing triad everywhere.
- **Surfaces**: C-API 293/293 · Zig-API complete (full WASI parity) · lean CLI · memory-safety sound · dogfooded into
  cw. Runners ReleaseSafe (ADR-0177; `check_releasesafe_runners.sh`).
- **EH**: cross-instance JIT EH on BOTH arches (arm64 `4f73d9ee` + x86_64 `c534afca`). Interp + JIT EH corpus green.
- **Debt**: 61 entries; `now`-class = D-462 (feature-separation, ADR-0193, user-gated), D-460 (v128-GC partial),
  D-461 (SIMD-spill, blocks D-460). D-335 (WASI 0.3 core) DONE. Rest front-tagged (future-bucket/parked).
- **Realworld corpus**: 56 fixtures (c/cpp/emcc/go/tinygo/rust/zig), interp 56/0; JIT run-stage opt-in.
- **Tag**: `v2.0.0-alpha.3` tag-only (no Release → Latest stays v1.11.0), USER-ONLY.

## Key refs

- [`flake.nix`](../flake.nix) `devShells.gen` / `.#gen-wasip3` — fixture toolchains. [`docs/zig_api_design.md`](../docs/zig_api_design.md).
- ADRs: **0156** (NO autonomous release) · **0153** (rework) · **0187-0191** (CM-async) · **0185** (x86_64 EH) ·
  **0099** (file-size caps) · **0126** (iso-recursive canonical equality).
- lessons INDEX: `.dev/lessons/INDEX.md` (keyword index for Step 0.4).
