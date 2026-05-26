# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `78eb1d14` — 10.E-payload-prop Cycles 1-4 shipped.
  Cycle 4 replaces Cycle 3's zero-write with real pop-N+store-N
  in throw.emit (both arches; gpr-class only per ADR-0120 §3).
  IT-6 N=0 tagged-catch tests still green. Mac local + cross-
  compile x86_64-linux green. Ubuntu verify pending Step 0.7.
- **10.D = CLOSED 2026-05-25**, **10.M (incl D-181 ungate),
  10.R 1..5, 10.TC-1, 10.G-i31-ops/2/3, 10.E (IT-1..IT-6 codegen
  foundation + interp catch_/catch_all dispatch + tag-equality)**:
  SHIPPED.
- **D-181 = CLOSED `f37977df`** — memory64 i64-idx runner test
  ungated for x86_64 SysV; ubuntu verified @ HEAD `228d2d79`.
- **D-180 structural defenses SHIPPED** (`2808bc81` + `a98c7b1f`):
  x86_64 `usesRuntimePtr` whitelist drift detector +
  `test_discipline.md` §4 (host-only gates pair with debt row OR
  spec-pinned rationale) + lesson
  `2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md`.

## Active bundle

- **Bundle-ID**: 10.E-payload-prop
- **Cycles-remaining**: ~1 (Cycles 1-4 shipped: `d27c6857`, `36a53773`, `dcdedd87`, `78eb1d14`)
- **Continuity-memo**: payload propagation through
  `Runtime.eh_payload_buf: [16]u64` + `EmitCtx.tag_param_counts:
  []const u32 = &.{}` threading per ADR-0120. Throw emits
  pop-N+store-to-buf; try_table.emit synthesizes landing-pad
  load-from-buf+push. v128/exnref tag params deferred to v0.2.
- **Exit-condition**: `runI32Export: throw + catch_ with i32
  payload returns 88` test passes on Mac aarch64 + Linux x86_64
  SysV (currently silent-drops, returns 0; probe verified this
  cycle).

## ROADMAP §10 progress

- DONE (8/13): 10.0 / 10.C9 / 10.J / 10.F / 10.Z / 10.T / 10.D /
  10.E (foundation; bundle 10.E-payload-prop completes scope).
- IN-PROGRESS (3): 10.M (D-181 closed; realworld toolchain-blocked) /
  10.R (5/5; gated on 10.G) / 10.TC.
- Pending (2): 10.G / 10.P (close gate).

## Active task — Cycle 5 of 10.E-payload-prop bundle (last)

Cycle 4 (`78eb1d14`): throw.emit pop+store-N + write N. The
payload now flows throw-site → eh_payload_buf. Cycle 5 closes
the bundle with the catch-side load+push.

**NEXT (Cycle 5)** — catch landing pad load+push + end-to-end
test:
- Identify the emit point: when a catch label's matching `end`
  patches `Builder.entries[entry_idx].landing_pad_pc`, this is
  the byte position where the catch block's body begins. The
  load+push code must sit between landing_pad_pc and the block
  body. Two options:
  (a) emit the load+push code BEFORE patching landing_pad_pc;
      landing_pad_pc points to the load+push sequence's first
      byte (preferred — minimal API change).
  (b) emit landing pad as a fixed-size stub elsewhere and patch
      landing_pad_pc to it (more flexible but adds linker work).
- Pick (a). At the catch-label `end` op in arm64/emit.zig +
  x86_64/emit.zig, look up the matching HandlerEntry's kind +
  tag_idx → tag_param_counts[tag_idx] = N. Emit:
  - For i in [0, N): LDR Xstage, [X19, #(eh_payload_buf_off
    + i*8)]; allocate a fresh vreg and store via gprStoreSpilled.
  - For catch_ref / catch_all_ref: additionally LDR exnref
    pointer + push as fresh vreg (deferred to v0.2 per ADR-0120
    §3 if exnref is v0.2 scope).
- Same-cycle end-to-end test: `runI32Export: throw + catch_
  with i32 payload returns 88` — currently silent-drops (returns
  0); ungate to green after Cycle 5 lands.
- Cycle 6 (post-bundle): spec-corpus wiring + close 10.E close
  gate.

## Next candidates (after bundle close)

- **10.TC codegen** — return_call / return_call_indirect /
  return_call_ref JIT emit + frame_teardown helper. ADR-0112 +
  ADR-0113 §A foundations already shipped.
- **10.TC interp end-to-end runner test** — 10.TC-1 + 10.TC-1b
  shipped; e2e runI32Export-shape test would catch regressions
  before JIT codegen lands.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted. Loop
  proceeds with the Proposed design; user can intervene at any
  cycle boundary.
- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0114 D1/D6 (EH design + zwasm_throw trampoline),
  ADR-0119 (naked-Zig trampoline), ADR-0120 (Proposed; this
  bundle's design).
- Integration plan `.dev/phase10_eh_integration_plan.md` §IT-3
  (now superseded by ADR-0120 for marshalling shape).
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md`.
- Lessons (Phase 10 EH cycle):
  - `2026-05-26-eh-codegen-foundation-atom-rhythm.md` (`e62db476`)
  - `2026-05-28-eh-test-wrapper-host-fp-walk-segv.md`
  - `2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md`
