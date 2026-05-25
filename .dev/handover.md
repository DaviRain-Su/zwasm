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
- **10.R sub-chunks 1..5 = SHIPPED**: ref.as_non_null /
  br_on_null / br_on_non_null / call_ref / return_call_ref。
  parent row `[ ]` 留め — `(ref $sig)` typed reftype precision
  が 10.G で typed catalogue 拡張時に validator を引き締めるまで
  scope 不完全。
- **10.TC-1 = SHIPPED** (`a83e095f`): return_call + return_call_indirect
  interp impl + tailReturn helper。
- **10.TC-1b = SHIPPED** (`b7562e5c`): validator unit test
  coverage (6 tests)。
- **10.G-i31-helpers = SHIPPED** (`e79bb7a1`): pack/unpack helpers
  under `feature/gc/i31.zig`。
- **10.G-i31-ops = SHIPPED** (`52a6c225`): 3 i31 ops interp impl
  + Value helpers + 0xFB GC prefix dispatcher。
- **10.E-1 = SHIPPED** (`ffb56dd7`): tag section parse skeleton。
- **10.E-2 = SHIPPED** (`390856f8` + `cec18589`): decodeTags +
  TagEntry + sections.zig FILE-SIZE-EXEMPT marker。
- **10.G-2 = SHIPPED** (`d5810162`): needs_gc_heap parse-time
  predicate (byte-scan type section).
- **10.E-3a = SHIPPED** (`c2238c9a`): BlockKind.try_table enum
  entry + validator labelType arm。
- **10.E-3b = SHIPPED** (`da8880a9`): try_table opcode 0x1F +
  catch-vec skeleton。
- **10.E-4 = SHIPPED 2026-05-25** (`753aec8f`): throw / throw_ref
  opcodes (0x08 / 0x0A) — validator + interp Trap.UncaughtException
  emission。
- **10.E-5a = SHIPPED 2026-05-25** (`da1cec05`): EH catch
  metadata storage shape filled in on ZirFunc (`eh_landing_pads`
  + flat `eh_catch_entries` per ADR-0114 D3); lowerer wires
  catch-vec decode into LandingPad with half-open slice; 5
  lower_tests covering empty / mixed / ref-variants / nested /
  malformed. Detail: phase_log §10.E。
- **Mac `zig build test-all`**: green (scope=unclear)。

## Phase 10 progress

ROADMAP §10 = 13-row task table。
- DONE (7/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D
- IN-PROGRESS:
  - 10.M (7/8 sub-chunks; spec-corpus + realworld + 5b deferred)
  - 10.R (5/5 ops shipped; parent close gated on 10.G typed reftype)
  - 10.TC (1/N sub-chunks; 3 interp tail-call ops done; codegen +
    cross-module + spec corpus + regalloc terminator-class 残)
- Pending: 10.E / 10.G / 10.P

## Active task — 10.E-5b interp unwinder

Consume `func.eh_landing_pads` + `func.eh_catch_entries` (landed
10.E-5a) from the interp dispatch loop. On `Trap.UncaughtException`
emitted by `throwOp` / `throwRefOp`: walk the label stack
inward-out to find the enclosing `.try_table` BlockInfo, look up
its `LandingPad` by `block_idx`, linear-scan its catches for tag
match (incl. `catch_all` variants), restore operand-stack height
to the chosen label's height, push tag params (and exnref for
`_ref` variants), jump pc to the catch's `label_idx` target.

Refs: `src/runtime/trap.zig:UncaughtException`,
`src/interp/mvp.zig:{throwOp, throwRefOp, blockOp}`,
`src/validate/validator.zig:opThrow` (tag-param popping pending
Module.tags wiring at 10.E-N).

**Next sub-chunk candidates (names only, NO predictions)**:
- 10.E-5b — interp unwinder (the active task above)
- 10.E-N — Module.tags wiring through validator (tag_idx range +
  tag-params popping on throw)
- 10.G-3 — heap-top reftype detection extension
- 10.G-4 — struct ops (needs GC heap impl first)
- 10.M-5b — SIMD memarg memory64 (validator + lower + codegen)
- 10.TC-3 — regalloc terminator-class + codegen tail-call

## Open questions / blockers

なし。impl 着手可。

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1338+
- **Phase 10 design plan**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
