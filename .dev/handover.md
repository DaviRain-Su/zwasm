# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **10.D = CLOSED 2026-05-25**: 全 7 ADR (0111-0117) Accepted、
  impl rows unlocked。
- **10.M sub-chunks 1..fixture-2 = SHIPPED**: memory64 impl
  (parser/validator widening + Runtime.memories[] + MemArgExtra +
  codegen wrap-checks + v2_0 gate + edge_cases fixtures)。
- **10.R-1..4 = SHIPPED**: ref.as_non_null / br_on_null /
  br_on_non_null / call_ref。
- **10.R-5 = SHIPPED 2026-05-25** (`6129255e`): return_call_ref impl。
  lower 0x15 + uleb typeidx、validator opReturnCallRef (typeidx +
  pop reftype + pop params + verify callee.results == fn.results
  + markUnreachable)、interp returnCallRefOp in mvp.zig (callRefOp +
  returnOp composition; not a true tail call, frame_stack still
  grows during invoke — stack-non-growing variant deferred to
  10.TC ADR-0113 §A)。3 unit tests (null / matching tail-promote /
  sig mismatch)。
- **Mac `zig build test-all`**: green (scope=unclear → test-all)。

## Phase 10 progress

ROADMAP §10 = 13-row task table。
- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS: 10.M (7/8 sub-chunks; spec-corpus + realworld deferred)、
  10.R (5/5 ops shipped; parent close pending feature/ module +
  (ref $sig) typing)
- Pending: 10.TC / 10.E / 10.G / 10.P

## Active task — 10.R parent close prep

`phase10_design_plan_ja.md` §3.2 source-of-truth。All 5 function-
references ops shipped。10.R parent row `[x]` flip requires:

1. `src/feature/function_references/register.zig` を placeholder
   から本実装に: 5 ops の register を 1 か所 (wasm_3_0 disabled
   時の DCE が hub から効くように)。**Note**: 現在 register は
   既に `src/api/instance.zig` 内 wasm_3_0_enabled gate 経由で
   発動済み (`ext_function_references.register` +
   `mvp.register` 内 unconditional slot)。feature/ 側 register が
   再構築すべきか、それとも本当に placeholder で良いか要確認。
2. `(ref $sig)` typed function references typing — 10.G で typed
   reftype catalogue が拡張された後に validator が引き締まる。
   現状は funcref / externref のフラット polymorphism 止まり (10.R-1..5
   全て同じ caveat)。

**10.R-parent-close NEXT**: 上記 (1) `feature/function_references/
register.zig` の register() 本実装 — `wasm_3_0/function_references.zig`
の register() を呼び出す形にし、`api/instance.zig` の直接 import
を feature/ 経由に切り替える (ADR-0023 §3 declared-feature pattern
に揃える)。これで 10.R 本体は close 可能 ((ref $sig) typing は
10.G で別途)。

**Other Phase 10 candidates** (after 10.R close):
- 10.M-5b (deferrable): SIMD memarg memory64
- 10.M-spec-corpus (deferrable): memory64 spec testsuite wire-up
- 10.M parent-close
- 10.TC tail-call (regalloc terminator-class)
- 10.E exception handling
- 10.G GC typing (+ typed function refs)
- 10.P proposal phasing close

**ADR-0113 callsite_metadata refactor**: 10.M は memory64 で
bounds_fixups を **触らない** (ADR-0111 D6 ↔ orthogonal)。

## Open questions / blockers

なし。impl 着手可。

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1338+
- **Phase 10 design plan**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.2
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
