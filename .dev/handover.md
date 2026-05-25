# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **10.D = CLOSED 2026-05-25**: 全 7 ADR (0111-0117) Accepted、
  impl rows unlocked。
- **10.M-5 = SHIPPED** (`96dafb3c`): validator memory64 widening + e2e test。
- **10.M-close = SHIPPED** (`b7556472`): -Dwasm=v2_0 symbol-absence gate。
- **10.M-fixture = SHIPPED** (`699f3b95`): edge_cases/p10/memory64/ store+load triple。
- **10.M-fixture-2 = SHIPPED 2026-05-25**: 追加 OOB-trap + page-edge
  fixtures。memory64 fixture set が basic round-trip + trap-boundary
  + exact-equals off-by-one カバー。p10 corpus 3/3 PASS、total
  111/111 (p7=40 + p9=68 + p10=3) PASS。
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
- 10.M-fixture [x] SHIPPED `699f3b95` (edge_cases p10/memory64 triple)
- 10.M-fixture-2 [x] SHIPPED (OOB-trap + page-edge fixtures)
- **10.M-5b NEXT**: SIMD memarg memory64 support。
  `validator_simd.zig::readSimdMemarg` で bit-6 handling、
  `lower_simd.zig::emitMemargLane` で memidx 抽出。v128.load/store
  on i64-indexed memory が validator-reject される現状を解消。
  arm64 op_simd.zig + x86_64 emit.zig SIMD load_lane sites は
  既存の lane=u8 → 新 packed (lane + memidx + ...) 移行が必要。
- 10.M-spec-corpus (deferrable): WebAssembly/memory64 spec testsuite
  (~127 .wast files) を spec runner に wire-up。
- 10.M-parent-close: ROADMAP §10 / 10.M row `[x]` flip。
  Requires spec corpus + realworld/p10/clang_wasm64/ green (ADR-0111 row text)。

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
