# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — D-054 is `now` (post-`4d6fc0b` regression); 9 `blocked-by:` rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/decisions/0033_pass_trace_extension.md` (8a.1 design) +
   `0028_diagnostic_m3_trace_ringbuffer.md` (parent).
6. `.dev/decisions/0031_zir_hoist_pass.md` + `0032_phase8_foundation_first_reorg.md` (recent ADRs).

## Current state — Phase 8 / §9.8a / 8a.1-c (ZirFunc.pass_diagnostics slot)

§9.8a foundation-first work in progress per ADR-0032. 8a.1-b
(trace.zig passEvent API) lands the ringbuffer channel of
ADR-0033's two-channel design; the next chunk lands the
per-function slot channel.

直近 commits (latest at top):

- (this commit) chore(p8): §9.8a / 8a.1-b roadmap update +
  D-054 OrbStack regression entry.
- `0b6408c` feat(p8): §9.8a / 8a.1-b — trace.zig passEvent API
  per ADR-0033.
- `93da390` docs(p8): §9.8a / 8a.1-a — ADR-0033 design
  framing.
- `c50296c` chore(p8): ADR-0032 + ROADMAP §9.8 reorg.

Mac local + with `-Dtrace-ringbuffer=true`: `zig build test` +
lint green. Mac `test-all` green. **OrbStack `test-all` carries
1 known-FAIL** (D-054 `as-loop-broke` regression introduced by
`4d6fc0b`; pre-8a.1-b, x86_64-only); 8a.5 cap-removal
investigation is the discharge path.

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; 8a.1-a/b [x]; **§9.8a /
8a.1-c NEXT**. Phase 8 残 rows = 8a.1-c/d/e + 8a.2-8a.6 + 8b.1-
8b.6.

## Active task — §9.8a / 8a.1-c: ZirFunc.pass_diagnostics slot **NEXT**

Per ADR-0033, add to `src/ir/zir.zig`:

- `PassRecord` struct (`pass: PassId`, `applied: u32`,
  `skipped: u32`, `extra: u32`).
- `PassDiagnostics` struct (`entries: []const PassRecord`).
- `ZirFunc.pass_diagnostics: ?PassDiagnostics = null` slot
  field, mirroring `?Liveness` / `?LoopInfo` shape.
- Slot helpers: `appendPassRecord(allocator, func, record)` +
  `deinitPassDiagnostics(allocator, pd)`. Owner discipline
  matches existing analysis slots — borrowed slice; freed by
  `deinitFuncResult` in `compile.zig`.
- 1-2 unit tests asserting slot starts null, append grows the
  entries slice, deinit frees cleanly.

Suggested chunk plan:

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8a.1-a | ADR `0033_pass_trace_extension.md` design framing       | [x] (`93da390`) |
| 8a.1-b | Extend `src/diagnostic/trace.zig` with `passEvent()`    | [x] (`0b6408c`) |
| 8a.1-c | `ZirFunc.pass_diagnostics: ?PassDiagnostics` slot + helpers | **NEXT** |
| 8a.1-d | Wire into compile.zig pipeline stages (lower/hoist/liveness/regalloc/emit) | [ ]      |
| 8a.1-e | Unit tests + 3-host gate; close 8a.1 [x]                | [ ]      |

After 8a.1 closes: 8a.2 (JIT-execution sentinel), 8a.3 (bench-
delta-per-commit), 8a.4 (`ZWASM_DIAG` env var), 8a.5 (D-053 +
**D-054** cap-removal investigation using the new infra), 8a.6
(8a boundary audit).

Then §9.8b begins: 8b.1 (Coalescer, bench-delta required) →
8b.2 (Regalloc upgrade) → 8b.3 (AOT skeleton) → 8b.4 (≥10%
aggregate) → 8b.5 (boundary audit) → 8b.6 (open §9.9).

## D-054 OrbStack regression (load-bearing for 8a.5 prep)

OrbStack `zig build test-all` shows 1/212 spec_assert FAIL:
`unreachable: as-loop-broke(()) → got 0xFD1BD386, expected 1`.
Reproducible on origin's `93da390` (pre-8a.1-b, doc-only) →
introduced post-`4d6fc0b` (8.4-d hoist cap=4 integration).
Mac aarch64 unaffected; x86_64-only. The 8a.1 pass-trace
counters + 8a.5 cap-removal investigation are the discharge
path; the as-loop-broke fixture becomes a regression detector.

windowsmini gate not yet exercised this cycle (will likely
show the same regression — same x86_64 JIT path).

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-054** (`now`) — OrbStack as-loop-broke spec_assert
  regression; 8a.5 discharge path.
- 9 `blocked-by:` rows — D-007 / D-010 / D-016 / D-018 / D-020
  / D-021 / D-022 / D-026 / D-028 / D-052; barriers all hold
  this resume.

D-053 promoted to ROADMAP row §9.8a / 8a.5 per ADR-0032.

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
