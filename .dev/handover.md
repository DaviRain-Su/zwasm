# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: this commit — 10.Z cycle-1 attempt (reverted)
  + chunk plan doc。`ZirInstr.payload u32 → u64` の mechanical
  widen で **131 compile errors** を観測 (120× expected-u32 +
  11× @bitCast size mismatch); ROADMAP の "失敗時 chunk revert"
  per 10.Z row text に従い revert; cycle-2 用の subagent-driven
  migration plan を `.dev/phase10_z_chunk_plan.md` に文書化。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。
- **Mac `zig build test`**: 1827/1841 passed (revert 後 baseline 維持)。

## Active task — 10.Z cycle-2 NEXT (subagent-driven mechanical migration)

10.Z = architectural chunk; attempt 1/3 used (cycle-1 cascade
measurement)。`.claude/rules/architectural_spike.md` の 3-cycle
cap 内。

| Row | Scope | Status |
|---|---|---|
| 10.0 / 10.C9 / 10.J / 10.F | done | `[x]` |
| **10.Z attempt 2 NEXT** | ZirInstr.payload u32 → u64 — subagent-driven mechanical migration per `.dev/phase10_z_chunk_plan.md` §"Cycle-2 strategy"。131 sites: (a) memory-op handlers `wasm_1_0/memory.zig` + `wasm_2_0/bulk_memory.zig`; (b) `LowerInstr.payload` propagation (zir.zig:225 + lower.zig); (c) misc interp/codegen long-tail。emit_test_*.zig byte-identical 維持 verify | `[ ]` |
| 10.D / 10.T / 10.M / 10.R / 10.TC / 10.E / 10.G / 10.P | pending | `[ ]` |

**10.Z cycle-2 exit criterion**:
(a) `ZirInstr.payload: u64` + `LowerInstr.payload: u64` widened;
(b) call sites use `u64` directly OR @intCast where structurally
required (loadInt/storeInt helpers widen their offset param to u64);
(c) `zig build test` GREEN on Mac (baseline 1827/1841);
(d) emit_test_*.zig byte-identical maintained (regalloc + emit
only consume low 32 bits for Wasm 1.0/2.0 sources);
(e) ubuntu post-push verify GREEN。
詳細: `.dev/phase10_z_chunk_plan.md` §"Cycle-2 strategy"。

## Cycle-1 observations (carried into cycle-2)

- 120 sites have shape `helper(..., instr.payload)` where helper's
  offset param is u32 → widen helper to u64.
- 11 sites have `@bitCast` between u64-source and i32-dest (or
  vice-versa) → re-shape via @truncate / explicit @as.
- Top hot file: `src/instruction/wasm_1_0/memory.zig` (load/store
  family ~30 sites).
- No serialised-AOT breakage observed yet at compile time
  (AOT format may need own carve-out — verify at cycle-2 close).

## Phase 10 progress

ROADMAP §10 = 13-row task table。10.0/10.C9/10.J/10.F done (4/13);
10.Z attempt 1/3 (reverted); 10.D/10.T/10.M/10.R/10.TC/10.E/10.G/10.P
pending。

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1342 (row 10.Z)
- **10.Z chunk plan**: [`phase10_z_chunk_plan.md`](./phase10_z_chunk_plan.md)
- **Phase 10 design plan**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1 (Z.1 ZirInstr 128-bit 拡張)
- **Architectural-chunk cap**: `.claude/rules/architectural_spike.md` (3-cycle limit)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
