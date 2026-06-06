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

## Active bundle (ADR-0118 D6) — Phase 17.2 Wide-arithmetic (v0.2, ADR-0168)

- **Bundle-ID**: 17.2-wide-arith
- **Goal**: implement the Wasm wide-arithmetic proposal — `i64.add128` (0xFC 19), `i64.sub128` (0xFC 20),
  `i64.mul_wide_s` (0xFC 21), `i64.mul_wide_u` (0xFC 22). 128-bit integer math; ZirOps reserved
  `zir_ops.zig:584-588`, all of validator/lower/interp/JIT absent.
- **Continuity-memo**: add128/sub128 = 4→2 [a_lo,a_hi,b_lo,b_hi]→[r_lo,r_hi]; mul_wide_{s,u} = 2→2 [a,b]→[lo,hi].
  **CHUNK-1 INVESTIGATION DONE — multi-result infra ALREADY EXISTS**: liveness opens a fresh vreg per push
  (`liveness.zig:558` loops `while i<eff.pushes`) so `pushes=2` works; the call-to-multi-result path
  (`captureCallResult` @arm64/op_call.zig) is the emit precedent (loops results, `next_vreg+=1` + append each). So
  NO new regalloc/liveness infra — just validator (pushType×2) + lower + interp + JIT-emit (mirror
  captureCallResult for the 2 result vregs) + new encoders. Interp is trivial via Zig native `u128`/`i128`
  (assemble→`+%`/`*`→split lo/hi). 0xFC dispatch: `validator:dispatchPrefixFC` (@2129, handles 0-17) +
  `lower:emitPrefixFC` (@797). **Missing encoders**: arm64 ADDS/ADCS/SUBS/SBCS/UMULH/SMULH (inst.zig; MUL@655);
  x86_64 ADC/SBB + MUL/IMUL RDX:RAX (inst_alu.zig; encImulRR 2-op@180). Interp handlers: `instruction/wasm_1_0/`.
- **Plan**: ~~chunk 1 investigate~~ + ~~chunk 2 interp @8f807c19~~ + ~~chunk 3 JIT @231d4536~~ ALL DONE.
  17.2-wide-arith COMPLETE (validator+lower+interp+JIT, 4 ops, both arches). JIT: arm64 ADDS/ADC/SUBS/SBC/UMULH/
  SMULH; x86_64 ADC/SBB/MUL1/IMUL1 (RAX/RDX accumulators, reserved). 2-result emit (next_vreg++×2). 4 edge fixtures
  green Mac arm64 + x86_64-macos + 3 cross. Operand order matches v1 oracle. **NEXT = close bundle on ubuntu+
  windows confirm of 231d4536 (verify next Step 0.7), then open next v0.2 feature (custom-page-sizes:
  parse flag 0x08 exists @sections.zig:896 but unsupported).**
- **17.1-atomics DONE+CONFIRMED 3-host @9eb84833** (full op set fence+load/store/rmw/cmpxchg+notify/wait, interp+
  JIT both arches; Mac+ubuntu+windows all green — windows wasm-suites edge/wast/spec/simd/realworld 0-fail; the
  lone win "1 failed" = **D-028** known test-runner-respond heisenbug (Defender/IPC), recorded segv streak-0, NOT
  an atomics regression). **D-299** (inline load/store JIT misaligned-trap) still DEFERRED (callouts get it right).
- **Exit-condition**: `test/edge_cases/p17/wide_arith/*` green 3-host — add128 (carry across lo→hi), sub128
  (borrow), mul_wide_s/u (full 128-bit product hi:lo), with the multi-result correctly pushed.
- **Cycles-remaining**: ~3-4 (architectural: multi-result + 4 ops + new encoders). No tag (ADR-0156).

## Current state

- **Phase 17 (v0.2) IN-PROGRESS** (ADR-0168); **17.1-atomics DONE+3-host-confirmed @9eb84833** (full op set,
  interp+JIT both arches; win lone fail = D-028 known flake). **17.2-wide-arith COMPLETE @231d4536** (4 ops,
  validator+lower+interp+JIT both arches; Mac+Rosetta green, ubuntu+windows confirm pending Step 0.7). NEXT =
  close bundle → custom-page-sizes. D-299 deferred.
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
