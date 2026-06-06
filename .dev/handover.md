# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## NEVER-IDLE PROTOCOL (read first — user-directed 2026-06-06)

The loop **NEVER idles in "minimal turns."** The 完成形 v0.1 surface is done, but the user **UNBLOCKED v0.2 AND
v0.3 feature work** (2026-06-06) — "AIが思いのほか早いのでどんどんやろう." **Work priority each resume:**
1. **v0.2 / v0.3 features** — the primary forward track now (ROADMAP §17 / `.dev/proposal_watch.md`: threads,
   wide-arith, relaxed-SIMD, custom-page-sizes, component-model, …). Survey → sequence → TDD-implement. **No
   release/tag ever** (ADR-0156 stands — user reconfirmed "タグは切らない").
2. When between features OR a feature is gated → **sweep `.dev/remaining_sweep.md`** (Bucket A ledger-prune → B
   actionable-low-value → C deferred) — never idle, sweep the leftover systematically.
3. **D-279 + similar are NEVER "left alone"** (user: "放置せず常にシステムは動作するように") — keep it actively
   progressing: the H3 diagnostic is deployed; re-kick windows when work lands so a reproduction is always being
   hunted; verify the signal at every Step 0.7.
Idle/minimal turn is now a BUG, not a steady-state. Dogfooding (D-264) is **DONE** (cw v1 side succeeded).

## Active bundle (ADR-0118 D6) — Phase 17.1 Threads/Atomics (v0.2, ADR-0168)

- **Bundle-ID**: 17.1-atomics
- **Goal**: implement the WebAssembly threads/atomics `0xFE`-prefix op set (ZirOps already reserved
  `zir_ops.zig:596+`). Single-threaded substrate (ADR-0168): atomic load/store/rmw/cmpxchg = aligned seq-cst
  memory ops; `atomic.fence` = no-op; wait→trap-on-non-shared / notify→0.
- **Continuity-memo**: only notify/wait JIT remains (interp done). Mirror rmw/cmpxchg callout: TRAILING JitRuntime
  slots + `mem0_shared` flag + usesRuntimePtr/regalloc_compute predicates + edge fixtures → bundle exit. See NEXT.
- **DONE (fence+load/store+rmw+cmpxchg, full JIT both arches)**: 0xFE dispatch in `validator:dispatchPrefixFE` +
  `lower:emitPrefixFE`. EXACT natural-align (`readMemargCheckAlignExact`) + align-trap-BEFORE-bounds. fence
  @9971b708 (no-op); load/store interp+JIT (@e1a18357/@e6c22a57/@85b8f150) — JIT x86_64 fix @fbdefda9 (Win64 gate
  caught `emitMemOp` store-group `unreachable` + `usesRuntimePtr` garbage-R15, D-180-class; `i32_atomic_store` is
  the regression fixture); rmw @5b38c895 + cmpxchg @ab6972e1 via CALLOUT (TRAILING `atomic_rmw_fn` + opcode arg /
  `atomic_cmpxchg_fns[wlog2]` per-width array; 4-arg marshal mirrors table.grow, conflict-free; helpers are prod
  impls; trap_flag→epilogue; sidestep inline D-299 via jitTrapCode 14). 12+ fixtures green 3-arch incl.
  crossing-clobber + i64 res64 + narrow. Shared-mem parse gate OPEN @b54059fc.
- **D-299 (inline load/store JIT misaligned-trap) = DEFERRED, ENV-CONSTRAINED**: B2's x86_64 align-trap didn't
  fire (native ubuntu). Needs native-x86_64+lldb (Mac/Rosetta unreliable for it). Error-path-only (well-formed
  programs never unalign; spec threads-suite not wired → gate green); interp traps correctly. rmw/cmpxchg/wait
  callouts already get it RIGHT (Zig-side check) — D-299 is now ONLY the inline load/store path.
- **notify/wait INTERP DONE @100e4644** (validate+lower+interp+liveness+4 unit tests): notify→0 (align+bounds
  trap; non-shared OK); wait→**trap ExpectedSharedMemory on non-shared** (new Trap kind=15), else 1(≠exp)/2(timed-
  out). Also wired jitTrapCode 14→unaligned_atomic (was MISSING — latent rmw/cmpxchg JIT align-trap fix) + 15;
  trapKindName updated (test-all-only runner, D-228 lesson).
- **NEXT = notify/wait JIT** (callout, mirror rmw/cmpxchg): add `atomic_notify_fn(rt,ea)` + `atomic_wait_fns[2]`
  (per-width) TRAILING slots + a **`mem0_shared` flag on JitRuntime** (set at setup from memories[0].shared — JIT
  rt has no MemoryInstance; wait helper needs it). notify emit pops count+addr (count unused); wait pops
  timeout+expected+addr (timeout unused). Add to usesRuntimePtr+regalloc_compute. Then edge fixtures → **bundle
  exit-condition MET**. 3-host RUN-verifies x86_64 (revert-on-red).
- **Exit-condition**: a `test/edge_cases/p17/atomics/*` (or spec atomics manifest) green 3-host with the full
  load/store/rmw/cmpxchg set + fence; wait/notify minimal-single-thread; shared-mem parse+validate.
- **Cycles-remaining**: ~many (large feature). No tag (ADR-0156).

## Current state

- **Phase 17 (v0.2) IN-PROGRESS** (ADR-0168); 17.1-atomics ACTIVE: fence+load/store/rmw/cmpxchg full JIT;
  **notify/wait INTERP done @100e4644**; NEXT = notify/wait JIT (last piece → bundle exit). rmw/cmpxchg callouts
  crack their own align-trap (D-299 remains only for inline load/store).
  Phase 16 (完成形) DONE. No release/tag ever (ADR-0156).
- Debt ledger: **65 entries, 0 `now`** (D-264 dogfooding discharged). Remaining = `.dev/remaining_sweep.md`
  (Bucket A prune / B actionable-low / C deferred / D externally-blocked) — sweep between features, never idle.
- **D-279** Win64 SIMD heisenbug: H3 stack-overflow diagnostic deployed; re-kick windows as work lands to keep
  hunting the reproduction (user: never leave it idle). Mac-side investigation walled (needs the Win64 signal).

## 完成形 v0.1 surface COMPLETE (history — 2026-06-06)

All three surface audits DONE: CLI→**D-295** (~85% + intentionally lean, declines per ADR-0159 ≠ gaps). C-API→
**ZERO gaps** (D-296; 293/293). Zig-API→**COMPLETE** (D-296; `Module.imports/exports` + `Memory.grow/sliceAt` +
`Engine.linker()` + `Linker.defineInstance`; `docs/zig_api_design.md` synced). Memory-safety ALL areas swept
**SOUND** (D-297 cross-module aliasing; WASI fd lifecycle; 3 audit "CRITICAL" labels dissolved under verification
→ discipline: always adversarially verify audit criticals; lesson `fd0a1914`). Forward track now = **v0.2
features** (atomics bundle ACTIVE) + remaining_sweep between features (NEVER-IDLE above).

**D-279 (Win64 SIMD-JIT heisenbug — one open RED-class)**: leading hypo **H3 = Win64 1 MB stack overflow** (vs
Mac/Linux 8 MB). H3 diagnostic LANDED+validated @`b86ac7fc` (`EXCEPTION_STACK_OVERFLOW` VEH → `[d-279-veh]
STACK-OVERFLOW` WriteFile, diagnostic-only) but UNFIRED. Future crash self-IDs: `[d-279-veh] STACK-OVERFLOW` → H3
CONFIRMED (extend stack-limit guard to that path); exit-3 WITHOUT it → H3 refuted (re-open). Loop re-kicks windows
per batch so a repro is always hunted.

**Blocked / parked**: 31 blocked-by (call_ref §10.R / D-177 WASI-config / D-178 Global-Memory / future proposals).
**D-290** = 3 distillers direction-gated (wasm-tools↔wabt divergence; wabt stays). **D-264** dogfooding gated.

## Step 0.7 (next resume) — verify remote logs

- **ubuntu**: re-kicked each turn (D6 always). Verify `[run_remote_ubuntu] OK` in `/tmp/ubuntu.log`. @`92c8fb3b`
  was RED — `wast_runtime_runner.zig:967 trapKindName` missed `unaligned_atomic` (test-all-only runner; Mac `zig
  build test` doesn't compile it). FORWARD-FIXED @`5202d0b0` (lesson `trapkind-variant-breaks-test-all-only-
  runner-switch` — should've run `zig build test-runtime-runner-smoke` pre-push; verified 5/0). Verify GREEN this
  resume @ new HEAD. Red → auto-revert (D3).
- **windows**: batch kicked @`6944105f` came back **RED** — but it was the **p17 atomic-store COMPILE crash**
  (exit-3, `op_memory.zig:144 else=>unreachable`), a real x86_64 bug NOT D-279 (per D7: investigated → real →
  FIXED @`fbdefda9`). **D-279 itself stayed silent** in that same run (simd_assert_runner 13351/0, no veh, no
  exit-3 from SIMD) → silent streak holds. **Re-kick windows this turn** to confirm the atomics fix is green on
  Win64 (the gate's value: it caught a bug Mac+ubuntu's `zig build test`-only path could miss until edge-RUN).
  Future SIMD crash self-IDs via `[d-279-veh] STACK-OVERFLOW` (H3) vs exit-3 w/o it (re-open). NOT auto-revert (D7).
- **Gate note**: `OK` = green; `Build Summary: N failed` (no OK) = RED. EXPECTED non-failures: `zig-host-hello`
  exit-42, `--__selftest-crash` exit-70, sha256 `verify: FAIL` (fixture-wrong-constant FALSE lead).

## Key refs

- **ADR-0156** (no autonomous release) · **ADR-0153** (rework campaign) · **ADR-0076** (3-host cadence D6/D7/D8)
  · **ADR-0109** (native Zig API) · **ADR-0014 §2.1** (zombie-parking lifetime, D-297).
- **D-296** = surface-audit record (C/Zig-API) · **D-297** = cross-module memory-safety audit · **D-279** =
  Win64 SIMD heisenbug (instrumented) · `.dev/proposal_watch.md` = v0.2.0 feature backlog.
