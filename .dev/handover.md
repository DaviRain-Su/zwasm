# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `dcdedd87` — 10.E-payload-prop Cycles 1-3 shipped.
  Cycle 3 threads CompiledWasm.tag_param_counts → EmitCtx (both
  arches) and consumes it in throw.emit by emitting a single
  zero-write to `eh_payload_len` before the trampoline call.
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
- **Cycles-remaining**: ~2 (Cycles 1-3 shipped: `d27c6857`, `36a53773`, `dcdedd87`)
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

## Active task — Cycle 4 of 10.E-payload-prop bundle

Cycle 3 (`dcdedd87`): EmitCtx threading + zero-write to
`eh_payload_len` at every throw site. The infrastructure is now
in place for the actual pop-N+store-N to land cleanly.

**NEXT (Cycle 4)** — throw.emit actual payload pop+store + first
red-then-green test for throw + catch_ with i32 payload:
- arm64 + x86_64 throw.emit: replace the current
  `eh_payload_len = 0` zero-write with the real pop+store
  sequence:
  - Read N = `ctx.tag_param_counts[tag_idx]` at emit time
    (compile-time-known).
  - Pop N vregs from `ctx.pushed_vregs`.
  - For each i in [0, N): load value from spill slot via
    `gprLoadSpilled`, store at `[runtime_ptr + eh_payload_buf_off
    + i*8]` (8-byte slot stride; align matches u64).
  - Write N (instead of 0) to `eh_payload_len`.
- Same-cycle observable test: probe the runI32Export "throw +
  catch_ with i32 payload returns 88" against current state —
  documents what currently still drops (the catch landing pad
  doesn't yet read the buffer). Cycle 5 wires try_table.emit's
  landing-pad-synth pop-from-buf+push-to-vregs.

Note: payload-buf offset = 296 fits in u14 (STR Wn imm14 / X-form
imm12*4 budget). Existing `encStrImmW(rt, rn, byte_offset: u14)`
encoder usable directly.

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
