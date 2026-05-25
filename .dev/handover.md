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
- **10.M-fixture-2 = SHIPPED** (`18bd07cd`): OOB-trap + page-edge fixtures。
- **10.R-1 = SHIPPED** (`fe97f615`): ref.as_non_null + wasm_3_0 register pattern。
- **10.R-2 = SHIPPED** (`86f37b3a`): br_on_null impl。
- **10.R-3 = SHIPPED** (`b31dc63f`): br_on_non_null impl + branchTo dedup helper。
- **10.R-4 = SHIPPED 2026-05-25** (`9a68cef9`): call_ref impl。
  lower 0x14 + uleb typeidx、validator opCallRef (typeidx range
  + pop reftype + pop params + push results)、interp callRefOp in
  mvp.zig (Zone 2; needs invoke + dispatch loop) — pops funcref、
  null→Trap.NullReference、decode FuncEntity、sigEq check else
  IndirectCallTypeMismatch、invoke via FuncEntity.runtime (ADR-0014
  §6.K.3 cross-module path)。3 unit tests in trap_audit.zig (null /
  matching / sig mismatch)。
- **Mac `zig build test`**: green (substrate baseline)。

## Phase 10 progress

ROADMAP §10 = 13-row task table。
- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS: 10.M (7/8 sub-chunks; spec-corpus + realworld deferred)、
  10.R (4/5 ops shipped)
- Pending: 10.TC / 10.E / 10.G / 10.P

## Active task — 10.R typed function references

`phase10_design_plan_ja.md` §3.2 source-of-truth (function-references
proposal は 10.D の 7 ADR と直交; design plan §3.2 が単独で normative)。

**Sub-chunk progress**:

- 10.M-1..fixture-2 [x] SHIPPED (10.M memory64 impl: parser/validator
  widening + Runtime.memories[] + MemArgExtra + codegen wrap-checks +
  v2_0 gate + fixtures; see prior handover for SHA list)
- 10.R-1 [x] SHIPPED `fe97f615` (ref.as_non_null impl)
- 10.R-2 [x] SHIPPED `86f37b3a` (br_on_null impl)
- 10.R-3 [x] SHIPPED `b31dc63f` (br_on_non_null impl)
- 10.R-4 [x] SHIPPED `9a68cef9` (call_ref impl; lives in mvp.zig)
- **10.R-5 NEXT**: `return_call_ref` impl。Wasm 0x15 + typeidx。
  Tail-call variant of call_ref: pops funcref + args; if null →
  Trap.NullReference; else sig-check funcref against typeidx then
  **replace** current frame (= tail call). Lives in mvp.zig (Zone 2,
  needs frame teardown + dispatch loop). Merges with 10.TC
  cross_module_tail_call when 10.TC opens (regalloc terminator-class
  extension per ADR-0113 §A); for now interp-only impl with
  re-derived frame swap mirroring `returnOp` then `callRefOp`.
- 10.M-5b (deferrable, lower priority): SIMD memarg memory64 (validator
  + lower; codegen for SIMD memory64 emit substantial; defer to post-10.R)。
- 10.M-spec-corpus (deferrable): memory64 spec testsuite wire-up。
- 10.M-parent-close: ROADMAP §10 / 10.M row `[x]` flip after spec
  corpus + realworld green。
- 10.R-parent-close: ROADMAP §10 / 10.R row `[x]` flip after
  call_ref + return_call_ref ship + feature/function_references/
  module materialised。

**ADR-0113 callsite_metadata refactor**: 10.M は memory64 で
bounds_fixups を **触らない** (ADR-0111 D6 ↔ orthogonal)。

## Open questions / blockers

なし。impl 着手可。

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1338+
- **Phase 10 design plan**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.2
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
