# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **10.D = CLOSED 2026-05-25**: 全 7 ADR (0111-0117) Accepted、
  impl rows unlocked。
- **10.M-1 = SHIPPED 2026-05-25** (`063e80e8`): parser+validator
  memory64 widening。
- **10.M-2 = SHIPPED 2026-05-25** (`939b7bbe`): Runtime データ shape。
  `MemoryInstance { bytes, idx_type, pages_min, pages_max }` +
  `Runtime.memories: []MemoryInstance` 追加。`rt.memory` は
  `memories[0].bytes` の pointer alias として残存 (`setMemory0Bytes`
  helper で同期)。~80 reader 触らず。multi-memory > 1 reject は維持
  (10.M-3 で MemArg memidx wire-up と同時にリフト)。Mac `test-all` GREEN。
- **Mac `zig build test`**: green (substrate baseline)。

## Phase 10 progress

ROADMAP §10 = 13-row task table。
- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS: 10.M (sub-chunk 1/6 shipped)
- Pending: 10.R / 10.TC / 10.E / 10.G / 10.P

## Active task — 10.M memory64 impl

Per ADR-0111 (Accepted)。`phase10_design_plan_ja.md` §3.1 source-of-truth。

**Sub-chunk progress**:

- 10.M-1 [x] SHIPPED `063e80e8` (parser+validator widening)
- 10.M-2 [x] SHIPPED `939b7bbe` (Runtime.memories[] + setMemory0Bytes alias)
- **10.M-3 NEXT**: `MemArg extra: packed struct(u32) { align_pow2: u5, memidx: u8, _: u19 }`
  per Wasm 3.0 §5.4.6 (parser + lowerer wire-up)。memarg align uleb の
  bit-6 を読んで memidx LEB が follow するか判定 (Wasm 3.0 §5.4.6)。
  ZirInstr.extra (u32) の新フォーマット導入 + lowerer で per-memidx
  routing (現状全 emit が memories[0] 固定)。memidx > 0 が emit-time
  に到達したら一旦 trap (multi-memory > 1 reject はまだ instantiate
  で hold)。
- 10.M-4: codegen — arm64/x86_64 で i64 wrap-check + 64-bit offset
  materialise (X17 MOVZ+MOVK 4-lane / R10 MOV imm64)。**i32
  fast-path byte-identical** を `emit_test_memory.zig` で機械検証。
- 10.M-5: spec corpus + edge_cases + `realworld/p10/clang_wasm64/`
  green。
- 10.M-close: `-Dwasm=v2_0` symbol-absence gate を
  `scripts/check_phase10_close_invariants.sh` に追加 (ADR-0111
  Revision 補強)。

**ADR-0113 callsite_metadata refactor**: 10.M は memory64 で
bounds_fixups を **触らない** (ADR-0111 D6 ↔ orthogonal)。

## Open questions / blockers

なし。impl 着手可。

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1338+
- **Phase 10 design plan**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1
- **ADR-0111** (Accepted): [`decisions/0111_memory64_design.md`](./decisions/0111_memory64_design.md)
- **10.M-1 survey**: `private/notes/p10-10M-1-survey.md`
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
