# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — D-054 `blocked-by` 8a.1-d/e + 8a.5; 9 other `blocked-by:` rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/decisions/0033_pass_trace_extension.md` (8a.1 design) +
   `0028_diagnostic_m3_trace_ringbuffer.md` (parent).
6. `.dev/decisions/0031_zir_hoist_pass.md` + `0032_phase8_foundation_first_reorg.md` (recent ADRs).

## Current state — Phase 8 / §9.8a / 8a.1-d (compile.zig pipeline wiring)

§9.8a foundation work in progress per ADR-0032. 8a.1-c
(`ZirFunc.pass_diagnostics` slot + `PassRecord` /
`PassDiagnostics` types + `deinitPassDiagnostics`) lands the
per-function channel of ADR-0033's two-channel design. Both
channels (ringbuffer + slot) now exist; the next chunk wires
the call sites.

直近 commits (latest at top):

- (this commit) chore(p8): §9.8a / 8a.1-c roadmap + handover +
  D-054 reframed as OrbStack-only, blocked-by 8a.1-d/e.
- `26b4fcf` feat(p8): §9.8a / 8a.1-c — ZirFunc.pass_diagnostics
  slot per ADR-0033.
- `0b6408c` feat(p8): §9.8a / 8a.1-b — trace.zig passEvent API.
- `93da390` docs(p8): §9.8a / 8a.1-a — ADR-0033 design framing.

3-host gate at `26b4fcf`: Mac green, windowsmini green (212/0/20
spec_assert + wasi 2/0), **OrbStack carries 1 known D-054 FAIL**
(`as-loop-broke`; OrbStack-only — Mac + windowsmini both green
on the same fixture). D-054 reframed: not a generic x86_64 bug
but an OrbStack/Rosetta interaction; structural discharge path
unchanged (8a.1 observability + 8a.5 investigation).

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; 8a.1-a/b/c [x]; **§9.8a /
8a.1-d NEXT**. Phase 8 残 rows = 8a.1-d/e + 8a.2-8a.6 + 8b.1-8b.6.

## Active task — §9.8a / 8a.1-d: compile.zig pipeline wiring **NEXT**

Per ADR-0033 + the 8a.1-b/c types now in place, wire
`passEnter` / `passExit` into each of the 5 pipeline stages in
`src/engine/codegen/shared/compile.zig`:

- `lower` — `lowerer.lowerFunctionBody`. Summary: `applied =
  body wasm-ops processed`, `extra = func.instrs.items.len`.
- `loop_info` — `loop_info_mod.compute`. Summary:
  `applied = loop_headers.len` (loop frames found),
  `skipped = blocks.items.len - loop_headers.len`.
- `hoist` — `hoist.run`. Summary: `applied =
  func.hoisted_constants.?.len`, `extra = synthetic_locals.?.len
  if any else 0`.
- `liveness` — `liveness.compute`. Summary: `applied =
  lv.ranges.len`.
- `regalloc` — `regalloc.compute`. Summary: `applied =
  alloc.n_slots`, `extra = high-water slot id`.
- `emit` — `emit.compile`. Summary: `applied =
  func.instrs.items.len`, `extra = out.bytes.len`.

For each stage: build a `PassRecord` after the pass returns;
append to a local `std.ArrayList(PassRecord)` running in the
wrapper; emit the `passEnter` / `passExit` ringbuffer events;
finally at function close, `.toOwnedSlice()` into
`func.pass_diagnostics.entries`. All gated by the `comptime
trace.enabled` branch.

`compile.zig`'s `deinitFuncResult` gains a
`deinitPassDiagnostics` call mirroring the existing `liveness`
/ `loop_info` cleanup.

Suggested chunk plan (continuing 8a.1):

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8a.1-a | ADR `0033_pass_trace_extension.md` design framing       | [x] (`93da390`) |
| 8a.1-b | Extend `src/diagnostic/trace.zig` with `passEvent()`    | [x] (`0b6408c`) |
| 8a.1-c | `ZirFunc.pass_diagnostics` slot + helpers               | [x] (`26b4fcf`) |
| 8a.1-d | Wire compile.zig pipeline (lower/hoist/liveness/regalloc/emit) | **NEXT** |
| 8a.1-e | Integration test + 3-host gate; close 8a.1 [x]          | [ ]      |

After 8a.1 closes: 8a.2 (JIT-execution sentinel), 8a.3 (bench-
delta-per-commit), 8a.4 (`ZWASM_DIAG` env var), 8a.5 (D-053 +
**D-054** cap-removal investigation), 8a.6 (8a boundary audit).

Then §9.8b begins: 8b.1 (Coalescer, bench-delta required) →
8b.2 (Regalloc upgrade) → 8b.3 (AOT skeleton) → 8b.4 (≥10%
aggregate) → 8b.5 (boundary audit) → 8b.6 (open §9.9).

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-054** (`blocked-by: 8a.1-d/e + 8a.5`) — OrbStack-only
  as-loop-broke spec_assert regression; observability
  precondition.
- 9 `blocked-by:` rows — D-007 / D-010 / D-016 / D-018 / D-020
  / D-021 / D-022 / D-026 / D-028 / D-052; barriers all hold
  this resume.

D-053 promoted to ROADMAP row §9.8a / 8a.5 per ADR-0032.

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
