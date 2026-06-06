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
- **Continuity-memo**: 0xFE prefix dispatch now LIVE in `lower.zig:emitPrefixFE` + `validator.zig
  :dispatchPrefixFE` (mirrors 0xFD). Remaining-absent: shared-mem flag still HARD-REJECTED
  (`parse/sections.zig:903` `is_shared→BadValType`) — only needed for wait/notify + spec shared fixture, NOT
  load/store/rmw (atomics need a memory but not a shared one). EXACT natural-align + runtime align-trap are the
  subtle correctness points (validator + per-arch JIT). ZirOp/per-op-file count consistency watch.
- **DONE**: `atomic.fence` (0x03) @9971b708 (no-op). **ALL atomic LOADS + STORES** (0x10-0x1d) — loads @e1a18357,
  stores @e6c22a57(non-JIT)+@85b8f150(JIT). Pattern: validate `opAtomicLoad`/`opAtomicStore` (EXACT natural align,
  `readMemargCheckAlignExact`; atomics need NO shared mem per wasm-tools `check_shared_memarg`) + lower emitMemarg
  + interp (`atomicLoadU`/`atomicStoreEa`, alignment-trap BEFORE bounds spec exec 8<14a, `Trap.UnalignedAtomic`/
  `TrapKind.unaligned_atomic`=14) + JIT-plain via emitMemOp arms+aliases + liveness. Both arches; edge+unit green.
- **D-299 (JIT misaligned-trap) = DEFERRED, ENV-CONSTRAINED**: B2's x86_64 runtime align-trap didn't fire (native
  ubuntu, reliable). My Mac/Rosetta investigation harness is UNRELIABLE (got-i32:0 vs NotImplemented for the same
  fixture across runs; load-only-atomic works fine on arm64 — so the iso NotImplemented was a harness artifact).
  Needs a reliable native-x86_64 + lldb env to crack (Mac/Rosetta can't). Error-path-only (well-formed programs
  never unalign atomics; threads spec-suite not yet wired → gate green). Interp traps correctly; the central
  `emitMemOp` JIT align-trap is the single D-299 fix that covers ALL atomic ops once cracked.
- **ALL atomics INTERP DONE**: rmw binops @96231c18 (42 ops, `rmwHandler` factory) + cmpxchg @78aa7dd2 (7 ops,
  `cmpxchgHandler`, spec wraps exp+rep to N). validate `opAtomicRmw`/`opAtomicCmpxchg` + lower + liveness (2→1 /
  3→1) + interp tests. The whole 0x10-0x4e set is interp-complete (loads+stores+rmw+cmpxchg). NO JIT for rmw/
  cmpxchg yet (loads+stores HAVE JIT).
- **NEXT = rmw + cmpxchg JIT emit** (the remaining JIT). NEW shape: load old + alu/compare + store + push old.
  Survey recipe captured (Step 0 done): reuse emitMemOp ea+bounds prologue (arm64 ea in ip0/X16, base X28;
  x86_64 ea in RDX, base RAX); **subtle: ea must survive load→alu→store, so DON'T stage the result/old through
  ip0/X16** — use a distinct scratch (arm64 X9-X13; x86_64 R10/R11). New `emitAtomicRmw`/`emitAtomicCmpxchg` per
  arch (op_memory.zig) + legacy-switch dispatch + edge fixtures. ALU encoders: arm64 encAddReg/encSubReg/
  encAndReg/encOrrReg/encEorReg (3-op); x86_64 encAddRR/encSubRR/encAndRR/encOrRR/encXorRR (2-op, .b/.w/.d/.q).
  cmpxchg = load+CMP+conditional-store. **x86_64 can't be RUN-verified locally (D-299 harness) → rely on ubuntu
  3-host gate** (revert-on-red like the B2 cycle). Reuse `Trap.UnalignedAtomic`. D-299 JIT-align-trap deferred.
- **Exit-condition**: a `test/edge_cases/p17/atomics/*` (or spec atomics manifest) green 3-host with the full
  load/store/rmw/cmpxchg set + fence; wait/notify minimal-single-thread; shared-mem parse+validate.
- **Cycles-remaining**: ~many (large feature). No tag (ADR-0156).

## Current state

- **Phase 17 (v0.2) IN-PROGRESS** (ADR-0168); 17.1-atomics ACTIVE: fence+loads+stores full; ALL rmw+cmpxchg
  INTERP done @78aa7dd2; NEXT = rmw+cmpxchg JIT emit. JIT misaligned-trap = D-299 (deferred/env-constrained).
  Phase 16 (完成形) DONE. No release/tag ever (ADR-0156).
- Debt ledger: **65 entries, 0 `now`** (D-264 dogfooding discharged). Remaining = `.dev/remaining_sweep.md`
  (Bucket A prune / B actionable-low / C deferred / D externally-blocked) — sweep between features, never idle.
- **D-279** Win64 SIMD heisenbug: H3 stack-overflow diagnostic deployed; re-kick windows as work lands to keep
  hunting the reproduction (user: never leave it idle). Mac-side investigation walled (needs the Win64 signal).

## ← LEAD: 完成形 surface work COMPLETE; entering maintenance/depth (2026-06-06 session)

**All three surface audits DONE** (user-steered direction): CLI→**D-295** (~85% + intentionally lean; declines
per ADR-0159 ≠ gaps; `--env` shipped). C-API→**ZERO gaps** (D-296; `capi_surface_gap.sh` 293/293; Phase-13
conformance verified+exceeded). Zig-API→**COMPLETE** (D-296): closed gap#1 (`Module.imports/exports`) + ALL
implementable residuals this session — `Memory.grow` (`f163e882`, shared `Runtime.growMemory`, test-spec 9/0),
`Memory.sliceAt` (`e5f34ff8`), `Engine.linker()` (`994a5aef`), `Linker.defineInstance` (`dba99bb8`, all 4 export
kinds). Surface reviewed CLEAN (subagent, no HIGH/MED), `docs/zig_api_design.md` synced (`e120cc15`), example
introspection demo (`40553679`).

**Memory-safety (完成形 dimension) — ALL major manual-memory areas now swept SOUND**: facade additions reviewed
clean; **cross-module aliasing** (**D-297**) SOUND (zombie-parking; disproved a table-UAF; documented the
Linker-outlives-Instances contract `477a9004`); **WASI fd lifecycle** swept this turn → SOUND (no double-close /
UAF / realloc-bug; stdio correct; Host correctly BORROWS preopen handles; `path_open` unimplemented so no owned
fds; the CLI preopen fds are an intentional documented process-lifetime choice run.zig:62, not a leak). The
audit's "fd-leak REAL BUG" was the **3rd overstated finding this session** to dissolve under verification.
**Discipline: always adversarially verify audit "CRITICAL" labels** (table-UAF, fd-leak, Linker-#6 all overstated).

**D-279 (Win64 SIMD-JIT heisenbug — one open RED-class issue)**: leading hypo **H3 = Win64 1 MB stack overflow**
(vs Mac/Linux 8 MB; deep SIMD path fits 8 MB, overflows 1 MB → Win64-only, intermittent, no-message, not-VEH —
the `[d-279-veh]` diag never fired + no 0xC0000005). H3 diagnostic LANDED+validated @`b86ac7fc`
(`EXCEPTION_STACK_OVERFLOW` VEH arm → `[d-279-veh] STACK-OVERFLOW` WriteFile, diagnostic-only, ADR-0105 D4
stands) but UNFIRED (silent streak 3). A FUTURE crash self-identifies: `[d-279-veh] STACK-OVERFLOW` → H3
CONFIRMED (extend the stack-limit guard to the overflowing path); exit-3 WITHOUT it → H3 refuted (re-open
enumeration). Pending external signal — the loop keeps re-kicking windows per batch so a repro is always hunted.

完成形 v0.1 surface (C/Zig/CLI) audited+documented+exampled; memory-safety all areas SOUND; debt swept;
proposal_watch current (2026-04-30); audit-overstatement lesson `fd0a1914`. Forward track now = **v0.2 features**
(atomics bundle ACTIVE) + remaining_sweep between features (NEVER-IDLE above).

**Blocked / parked**: 31 blocked-by (call_ref §10.R / D-177 WASI-config / D-178 Global-Memory / future proposals).
**D-290** = 3 distillers direction-gated (wasm-tools↔wabt divergence; wabt stays). **D-264** dogfooding gated.

## Step 0.7 (next resume) — verify remote logs

- **ubuntu**: re-kicked each turn (D6 always). Verify `[run_remote_ubuntu] OK` in `/tmp/ubuntu.log`. @`92c8fb3b`
  was RED — `wast_runtime_runner.zig:967 trapKindName` missed `unaligned_atomic` (test-all-only runner; Mac `zig
  build test` doesn't compile it). FORWARD-FIXED @`5202d0b0` (lesson `trapkind-variant-breaks-test-all-only-
  runner-switch` — should've run `zig build test-runtime-runner-smoke` pre-push; verified 5/0). Verify GREEN this
  resume @ new HEAD. Red → auto-revert (D3).
- **windows**: @`487e4bbd` run finished **clean GREEN** (`OK.` present, simd 13351/0, no veh, no exit-3) →
  D-279 silent **streak 3** (toward discharge-5); batch recorded @`92c8fb3b`. No kick pending — re-kicks when the
  next batch fires (≥6 ABI-touch / ≥12 else since 92c8fb3b). Future crash self-IDs via `[d-279-veh]
  STACK-OVERFLOW` (H3 CONFIRMED) vs SIMD exit-3 w/o it (segv, re-open). NOT auto-revert (D7). Don't poll-wait.
- **Gate note**: `OK` = green; `Build Summary: N failed` (no OK) = RED. EXPECTED non-failures: `zig-host-hello`
  exit-42, `--__selftest-crash` exit-70, sha256 `verify: FAIL` (fixture-wrong-constant FALSE lead).

## Key refs

- **ADR-0156** (no autonomous release) · **ADR-0153** (rework campaign) · **ADR-0076** (3-host cadence D6/D7/D8)
  · **ADR-0109** (native Zig API) · **ADR-0014 §2.1** (zombie-parking lifetime, D-297).
- **D-296** = surface-audit record (C/Zig-API) · **D-297** = cross-module memory-safety audit · **D-279** =
  Win64 SIMD heisenbug (instrumented) · `.dev/proposal_watch.md` = v0.2.0 feature backlog.
