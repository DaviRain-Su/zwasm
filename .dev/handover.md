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
- **10.M-2 = SHIPPED** (`939b7bbe`): Runtime data shape (MemoryInstance +
  memories[] + setMemory0Bytes alias)。
- **10.M-3 = SHIPPED** (`f0809d0c`): MemArgExtra packed + bit-6 memidx decode。
- **10.M-4a = SHIPPED** (`60ec148f`): codegen memidx==0 invariant assert (D3 anchor)。
- **10.M-4b = SHIPPED** (`d651d40b`): arm64 i64 wrap-check + memory0_idx_type plumbing。
- **10.M-4c = SHIPPED 2026-05-25** (`affef52f`): x86_64 i64 idx_type wrap-check
  mirror。`x86_64/ctx.zig::EmitCtx` + `InitArgs` に field 追加、
  `compile()` の discard を除去して thread through。`emitI32Load` (22-alias
  wrapper) に arm64 と同じ 2-stage gate。`emitMemOpI64`: `.q` MOV (full 64-bit)
  + u64 offset path。他は pre-existing X-form encoders 流用で byte-identical。
  10.M-4 全 arm64 + x86_64 完了。
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
- 10.M-3 [x] SHIPPED `f0809d0c` (MemArgExtra packed + bit-6 memidx decode)
- 10.M-4a [x] SHIPPED `60ec148f` (codegen memidx==0 invariant assert; D4 anchor)
- 10.M-4b [x] SHIPPED `d651d40b` (arm64 i64 wrap-check + memory0_idx_type plumbing)
- 10.M-4c [x] SHIPPED `affef52f` (x86_64 i64 wrap-check mirror)
- **10.M-5 NEXT**: spec corpus + edge_cases + `realworld/p10/clang_wasm64/`
  green。Wasm 3.0 memory64 fixture を整備し、parser + codegen + runtime
  end-to-end 検証 (i64 memory 宣言の module → instantiate → i32.load on i64 mem
  → 値検証)。test/edge_cases/p10/memory64/ に最小 fixture; realworld 側は
  clang_wasm64 toolchain 出力 (`clang --target=wasm64-...`)。
- 10.M-4d (optional, deferrable): `lower_simd.zig::emitMemargLane` の memidx
  抽出 (現在 align bit-6 を破棄中)。load_lane/store_lane の multi-memory 対応。
- 10.M-close: `-Dwasm=v2_0` symbol-absence gate を `scripts/check_phase10_close_invariants.sh` に追加。
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
