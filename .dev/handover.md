# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — discharge `Status: now` rows; review `blocked-by` triggers.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/optimisation_log.md` — F-NNN / R-NNN / O-NNN ledger (Phase 8 candidate landings).
6. `.dev/decisions/0028_diagnostic_m3_trace_ringbuffer.md` (parent of 8a.1) +
   `.dev/decisions/0033_pass_trace_extension.md` (8a.1 design framing).
7. `.dev/decisions/0031_zir_hoist_pass.md` + `0032_phase8_foundation_first_reorg.md` (recent ADRs).

## Current state — Phase 8 / §9.8a / 8a.1-b (per-pass trace ringbuffer extension)

§9.8a foundation-first work in progress per ADR-0032. 8a.1-a
(ADR-0033 design framing) closed this commit; the next chunks
extend `src/diagnostic/trace.zig` + `ZirFunc` slot per the
ADR's "What this ADR does NOT do" / Neutral follow-ups list.

直近 commits (latest at top):

- (this commit) chore(p8): §9.8a / 8a.1-a — ADR-0033 design
  framing for the per-pass trace ringbuffer extension.
- `c50296c` chore(p8): ADR-0032 + ROADMAP §9.8 reorg
  (foundation-first, bench-driven).
- `4d6fc0b` feat(p8): §9.8 / 8.4-d — hoist pipeline
  integration with MVP cap (D-053 partial).

Mac local realworld_run_jit baseline (carried forward as Phase
8a starting point): **52/55 compile-pass, 15/55 RUN-PASS** with
hoist active behind cap=4. 8a.5 (D-053 cap-removal
investigation) verifies this baseline is maintained AND hoist
application count increases — the ADR-0033 `applied`/`skipped`
counters are 8a.5's primary correctness signal.

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; **§9.8a / 8a.1-b
NEXT**. Phase 8 残 rows = 8a.1-b/c/d/e + 8a.2-8a.6 (foundation)
+ 8b.1-8b.6 (optimisation).

## Active task — §9.8a / 8a.1-b: extend `trace.zig` with `passEvent` API **NEXT**

Per ADR-0033, add to `src/diagnostic/trace.zig`:

- `Category.pass = 6` slot.
- `PassEvent` enum (`.pass_enter` / `.pass_exit`).
- `PassId` enum (`.lower` / `.loop_info` / `.hoist` /
  `.liveness` / `.regalloc` / `.emit` + `_` extension).
- `passEnter(func_idx, pass)` / `passExit(func_idx, pass,
  summary)` inline API.
- `PassSummary` struct (`applied` / `skipped` / `extra`) +
  `digest()` method packing `applied`/`skipped` into u32 with
  u16 saturation.
- 2-3 unit tests asserting (a) write + drain captures the
  pass entries; (b) ringbuffer ordering preserves enter →
  exit; (c) digest saturates correctly above u16 max.

Suggested chunk plan:

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8a.1-a | ADR `0033_pass_trace_extension.md` design framing       | [x] (this commit) |
| 8a.1-b | Extend `src/diagnostic/trace.zig` with `passEvent()`    | **NEXT** |
| 8a.1-c | `ZirFunc.pass_diagnostics: ?PassDiagnostics` slot + helpers | [ ]   |
| 8a.1-d | Wire into compile.zig pipeline stages (lower/hoist/liveness/regalloc/emit) | [ ]      |
| 8a.1-e | Unit tests + 3-host gate; close 8a.1 [x]                | [ ]      |

After 8a.1 closes: 8a.2 (JIT-execution sentinel), 8a.3 (bench-
delta-per-commit), 8a.4 (`ZWASM_DIAG` env var), 8a.5 (D-053
cap-removal investigation using the new infra), 8a.6 (8a
boundary audit).

Then §9.8b begins: 8b.1 (Coalescer, bench-delta required) →
8b.2 (Regalloc upgrade) → 8b.3 (AOT skeleton) → 8b.4 (≥10%
aggregate) → 8b.5 (boundary audit) → 8b.6 (open §9.9).

## ADR-0033 design summary (load-bearing for 8a.1-b/c/d/e)

Two channels, both gated by existing `-Dtrace-ringbuffer`:

1. **Ringbuffer (cross-cut, temporal)**: `Category.pass = 6`,
   `pass_enter`/`pass_exit` events; `payload_a` =
   `func_idx<<4 | pass_id_lo4`; `payload_b` = u32 digest of
   `applied`+`skipped` (u16 saturating).
2. **Per-function slot (local, structured)**: new
   `ZirFunc.pass_diagnostics: ?PassDiagnostics` carrying
   `[]PassRecord { pass, applied, skipped, extra }`. Slot
   ownership mirrors `?Liveness` / `?LoopInfo`.

`extra` semantics per pass (documented at each call site to
avoid `single_slot_dual_meaning.md` violation):

- `lower`: resulting `instrs.len`
- `loop_info`: 0
- `hoist`: synthetic locals added
- `liveness`: range-table length
- `regalloc`: high-water slot id
- `emit`: bytes emitted

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

10 active rows: D-007 / D-010 / D-016 / D-018 / D-020 / D-021
/ D-022 / D-026 / D-028 / D-052 — all `blocked-by:` with
concrete triggers; refresh on every resume per Step 0.5
barrier-dissolution check. None dissolved this resume.

D-053 (hoist cap-removal) was promoted to ROADMAP row §9.8a /
8a.5 per ADR-0032; no longer in `.dev/debt.md` Active.

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
