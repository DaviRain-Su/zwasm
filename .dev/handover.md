# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **10.D = CLOSED 2026-05-25**: 全 7 ADR (0111-0117) Accepted、
  impl rows unlocked。
- **10.M-5 = SHIPPED** (`96dafb3c`): validator memory64 widening + e2e test。
- **10.M-close = SHIPPED 2026-05-25** (`b7556472`): `-Dwasm=v2_0`
  symbol-absence gate at `scripts/check_phase10_close_invariants.sh`。
  `nm` で `emitMemOpI64` symbol が v2.0 build に 0 件 (= comptime DCE
  確認) を mechanical 検証。ADR-0111 D4 + Revision 2026-05-25。
- **Mac `zig build test`**: green (substrate baseline)。

## Phase 10 progress

ROADMAP §10 = 13-row task table。
- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS: 10.M (5/6 sub-chunks shipped; close-step remaining)
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
- 10.M-5 [x] SHIPPED `96dafb3c` (validator memory64 widening + e2e test)
- 10.M-close [x] SHIPPED `b7556472` (-Dwasm=v2_0 symbol-absence gate)
- **10.M-fixture NEXT**: `test/edge_cases/p10/memory64/` に
  最小 fixture (基本 store+load round-trip + page-edge access)。
  在所の in-source e2e test (`runner.zig`) と等価セマンティクスを
  .wat + .wasm + .expect triple として永続化 (ADR-0020
  edge_case_testing 準拠)。fixture runner (test/edge_cases/runner.zig)
  経由で `zig build test-all` から拾わせる。
- 10.M-5b (deferrable): SIMD memarg memory64 support
  (`validator_simd.zig::readSimdMemarg` + `lower_simd.zig::emitMemargLane`)。
- 10.M-spec-corpus (deferrable): WebAssembly/memory64 spec testsuite
  (~127 .wast files) を spec runner に wire-up。
- 10.M-parent-close: ROADMAP §10 / 10.M row `[x]` flip。
  Requires edge_cases + spec corpus + realworld/p10/clang_wasm64/
  green (ADR-0111 row text)。

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
