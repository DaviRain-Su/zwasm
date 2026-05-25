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
- **10.R-2 = SHIPPED 2026-05-25** (`86f37b3a`): br_on_null impl。lower 0xD4 +
  uleb labelidx、validator opBrOnNull (pop reftype + pop/push label types +
  push reftype back)、interp brOnNull (re-derive branch mechanics in Zone 1)。
  3 unit tests (register / non-null fall-through / null branch)。
- **Mac `zig build test`**: green (substrate baseline)。

## Phase 10 progress

ROADMAP §10 = 13-row task table。
- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS: 10.M (7/8 sub-chunks; spec-corpus + realworld deferred)、
  10.R (1/5 ops shipped)
- Pending: 10.TC / 10.E / 10.G / 10.P

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
- 10.M-fixture-2 [x] SHIPPED `18bd07cd` (OOB-trap + page-edge fixtures)
- 10.R-1 [x] SHIPPED `fe97f615` (ref.as_non_null impl)
- 10.R-2 [x] SHIPPED `86f37b3a` (br_on_null impl)
- **10.R-3 NEXT**: `br_on_non_null` impl。Wasm 0xD6 + labelidx。
  Mirror of br_on_null but inverted condition: if NON-null → branch
  (consumes reftype + branches with reftype as a branch value at top);
  else → fall through with reftype popped (= ref test consumed).
  Stack: pre `[t1*, reftype]` → fall `[t1*]`; branch dest expects
  `[t1*, reftype]` (the non-null narrowed ref is passed).
- 10.R-4..5 (cohort): call_ref / return_call_ref。call_ref はcross-module
  thunk-path re-use (`cross_module_call.zig`); return_call_ref は 10.TC
  cross_module_tail_call との合流。
- 10.M-5b (deferrable, lower priority): SIMD memarg memory64 (validator
  + lower; codegen for SIMD memory64 emit substantial; defer to post-10.R).
- 10.M-spec-corpus (deferrable): memory64 spec testsuite wire-up。
- 10.M-parent-close: ROADMAP §10 / 10.M row `[x]` flip after spec
  corpus + realworld green。

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
