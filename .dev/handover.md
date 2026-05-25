# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **10.D = CLOSED 2026-05-25**: 全 7 ADR (0111-0117) ユーザレビューで
  `Status: Accepted` flip 完了 + ROADMAP §12 (AOT) exit criterion
  追加済。impl rows 10.M / 10.R / 10.TC / 10.E / 10.G unlocked。
- **Mac `zig build test`**: green (substrate baseline)。

## Phase 10 progress

ROADMAP §10 = 13-row task table。
- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS / pending: 10.M (next) / 10.R / 10.TC / 10.E / 10.G / 10.P

## Active task — 10.M memory64 impl

Per ADR-0111 (Accepted)。`phase10_design_plan_ja.md` §3.1 source-of-truth。

**Sub-chunk 候補** (impl order; bundling rules per LOOP.md):

- **10.M-1 NEXT**: parser + validator widening。
  `MemoryEntry.idx_type: enum { i32, i64 }` discriminator を limits
  prefix の i64-flag bit から読む。`Module.memories: []MemoryEntry`
  multi-memory enable (Wasm 3.0 §5.4.6 memidx)。
  `comptime build_options.wasm_level < .v3_0` で `idx_type=.i64` を
  parse-time reject。
- 10.M-2: runtime refactor `memory: []u8 → memories: []MemoryInstance`
  (~80 call site cascade per ADR-0111 Consequences)。
- 10.M-3: `MemArg extra: packed struct(u32) { align_pow2: u5, memidx: u8, _: u19 }`
  per Wasm 3.0 §5.4.6。
- 10.M-4: codegen — arm64/x86_64 で i64 wrap-check + 64-bit offset
  materialise (X17 MOVZ+MOVK 4-lane / R10 MOV imm64)。**i32
  fast-path byte-identical** を `emit_test_memory.zig` で機械検証。
- 10.M-5: spec corpus + edge_cases + `realworld/p10/clang_wasm64/`
  green。
- 10.M-close: `-Dwasm=v2_0` symbol-absence gate を
  `scripts/check_phase10_close_invariants.sh` に追加 (ADR-0111
  Revision 補強)。

**ADR-0113 callsite_metadata refactor**: 10.M は memory64 で
bounds_fixups を **触らない** (memory ops の bounds-check のみ;
ADR-0111 D6 ↔ orthogonal)。bounds_fixups の 1-edge → N-edge
refactor は 10.TC / 10.E / 10.G のうち最初に impl する行が land する。

## Open questions / blockers

なし。impl 着手可。

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1338+
- **ROADMAP §12 (AOT)**: amended 2026-05-25 per ADR-0117 (stack-map
  exit criterion 追加)
- **Phase 10 design plan**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1 (memory64 source-of-truth)
- **ADR-0111** (Accepted): [`decisions/0111_memory64_design.md`](./decisions/0111_memory64_design.md)
- **ADR-0113** (Accepted; consumed when bounds_fixups refactor 発生): [`decisions/0113_callsite_metadata_regalloc_3axis.md`](./decisions/0113_callsite_metadata_regalloc_3axis.md)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
