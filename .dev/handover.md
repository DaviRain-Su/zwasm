# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — discharge `Status: now` rows; review `blocked-by` triggers.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/optimisation_log.md` — F-NNN / R-NNN / O-NNN ledger (Phase 8 candidate landings).
6. `.dev/decisions/0019_x86_64_in_phase7.md` / 0021 / 0023 / 0026 / 0027 / 0028 / 0029 — recent ADRs.
7. `.dev/phase8_transition_gate.md` — historical reference (gate now closed; 7.13 [x]).

## Current state — Phase 8 / §9.8a / 8a.1 (foundation-first reorg per ADR-0032)

§9.8 reorganised per **ADR-0032** into foundation-first
(§9.8a) + bench-driven optimisation (§9.8b). Phase-7 carry-
overs (8.0–8.3) and the partial-landed Hoist MVP (8.4 cap=4
behind `4d6fc0b`) all `[x]` as historical record. Active
work moves to **§9.8a foundation** rows.

直近 commits (latest at top):

- (this commit) chore(p8): ADR-0032 + ROADMAP §9.8 reorg into
  8a (foundation) + 8b (bench-driven); /continue skill +
  bench discipline; D-053 promoted to ROADMAP row 8a.5;
  handover retargets at 8a.1.
- `4d6fc0b` feat(p8): §9.8 / 8.4-d — hoist pipeline integration
  with MVP cap (D-053 partial).
- `8180c66` feat(p8): §9.8 / 8.4-d — D-053 hoist redesign
  landed (integration deferred again).

Mac local realworld_run_jit baseline (carried as Phase 8a
starting point): **52/55 compile-pass, 15/55 RUN-PASS** with
hoist active behind cap=4. 8a.5 (D-053 cap-removal investigation)
verifies this baseline is maintained AND hoist application count
increases (per 8a.1's pass-trace counters).

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; **§9.8a / 8a.1 NEXT**.
Phase 8 残 rows = 8a.1-8a.6 (foundation) + 8b.1-8b.6
(optimisation).

## Active task — §9.8a / 8a.1: per-pass diagnostic ringbuffer extension **NEXT**

The first §9.8a foundation row. Extends ADR-0028's Diagnostic
ring buffer with `passEvent(pass_name, summary)` entries.
Each pipeline stage (`lower` / `hoist` / `liveness` / `regalloc`
/ `emit`) emits enter + exit events with structured per-pass
summaries (e.g. `hoist: 4 const → local; 12 skipped`). `ZirFunc`
gains a `?PassDiagnostics` slot mirroring the `?Liveness` /
`?LoopInfo` shape. Surfaces opt-in via `ZWASM_DIAG=passes`
(landed in 8a.4).

Suggested chunk plan:

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8a.1-a | ADR `0033_pass_trace_extension.md` design framing       | **NEXT** |
| 8a.1-b | Extend `src/diagnostic/trace.zig` with `passEvent()`    | [ ]      |
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

## Reorg context (ADR-0032)

Phase 8 was reorganised into foundation-first / bench-driven
optimisation per user collaborative review. Background:

1. The 8.4 Hoist cycles (8.4-a/b/c/d) demonstrated that
   landing optimisations without observability infra produces
   debugging-cycle-per-attempt costs that don't amortise.
2. The /continue skill verified "baseline maintained" but
   didn't measure "did this optimisation actually speed
   anything up?" — bench-driven discipline was missing.
3. v1 development had a recurring "is the JIT actually
   running?" confusion that per-pass DBG prints kept being
   re-derived for. Centralised pass-trace + JIT-execution
   sentinel solves this structurally.

The 8.4 Hoist work is preserved verbatim in commit history
(`4f0be65` / `dba7cbb` / `8180c66` / `4d6fc0b`); the
cap=4 partial integration stays active. Cap removal is the
discharge condition for 8a.5 (the D-053 promotion).

**8.4-d landed** this cycle — local-set/local-get rewrite hoist
infrastructure committed (zir.zig helpers + synthetic_locals
slot + expanded HoistedConst + 4 emit consumer migrations + new
hoist/pass.zig + 4 unit tests pass). Pipeline integration
attempted but reverted again (52/55+15 → 42/55+8 RUN-PASS).

Updated barrier per **D-053**: single `UnsupportedOp` source in
`arm64/emit.zig` fires under post-hoist IR; `arm64/emit:` debug
print path doesn't trigger so the source is one of 17 silent
UnsupportedOp returns (lines 200, 301, 308, 324, 337, 354, 378,
745, 750, 782, 792, 795, 818, 827, 830, 853, 1155).

**Next concrete chunk**: bisect the UnsupportedOp source via a
small reproducer + size-thresholded hoist guard. Then either fix
the affected emit path or have hoist skip the pattern. Once
localised, pipeline integration becomes a 1-line edit in
`src/engine/codegen/shared/compile.zig`.

This cycle's productive output (besides the deferred
integration): zir.zig helpers + slot + HoistedConst expansion +
4 emit consumer migrations + hoist module rewrite + 4 unit
tests + ADR-0031 revision-history refinement entry + lesson
update.

## Phase 8 row design surface (carried forward)

Phase 8 substantive rows (8.4 Hoist / 8.5 Coalescer / 8.6
Regalloc upgrade / 8.7 AOT skeleton) all need careful per-row
ADR + design before implementation. Two surveys this cycle
exposed scope subtleties:

**8.4 (Hoist)** — `[ ]`. 8.4-a (ADR-0031 draft) + 8.4-b (MVP
module) committed; 8.4-c integration **reverted** because naive
instr-move breaks ZIR vreg renumbering. Lesson `2026-05-08-
hoist-vreg-semantic.md` records the gotcha; **D-053** carries
the local-set/local-get rewrite redesign forward. Estimated
~300 LOC redesign requires extending `func.locals` mutability
(or adding `synthetic_locals` slot) + helper at 2 emit consumer
sites — meaningful refactor surface that warrants its own
chunk-cycle.

**8.5 (Coalescer)** — `[ ]`. Survey at `private/notes/p8-8.5-
survey.md` (re-derivable) found:
- v1 W44 referenced in ROADMAP row text is a **misreference**
  — v1's W44 was SIMD register-class introduction, NOT MOV
  coalescing. The actual MOV-elimination work in v1 is
  unidentified.
- Current v2 emit pipeline already avoids most redundant MOVs
  (op_alu commute path, regalloc deterministic slot
  assignment). Trivial post-emit MOV-elim option (a) would
  catch only call-site `ORR X0, XZR, X19` style restores
  which are NOT redundant (they thread runtime_ptr to call
  arg-0). MVP yield is uncertain.
- Slot-aliasing option (b) is the canonical industrial path
  (~150-250 LOC) but needs interference-graph stub for
  correctness — non-trivial.

**8.6 (Regalloc upgrade)** — `[ ]`. Greedy-local → linear-scan
with live-range splitting + slot reuse. ADR-grade; large
chunk; resolves D-029.

**8.7 (AOT skeleton)** — `[ ]`. `zwasm compile foo.wasm -o
foo.cwasm` artifact; needs format ADR + serialiser. Distinct
from 8.4-8.6 (no JIT-pipeline overlap).

**Next concrete chunk (when /continue resumes)**: pick **one**
of the four rows above; survey-then-impl is the appropriate
shape per /continue skill chunk-table discipline. The most
tractable next entry is likely **8.4-d (D-053 redesign)** —
the design path is now clear (local-rewrite semantic + helper
function for emit consumers); the MVP module is reusable; the
result has a clear correctness gate (realworld_run_jit ≥
15/55).

This cycle's productive output: 4 commits (8.1-a, 8.1-b, 8.2,
8.3 close + 8.4-a/b/revert + design surface mapping for 8.5).

Open structural debts (current):

- D-007 / D-010 / D-016 / D-018 / D-020 / D-021 / D-022 /
  D-026 / D-028 / D-052 — all `blocked-by:` with concrete
  triggers; refresh on every resume per Step 0.5 barrier-
  dissolution check.

## Phase 7 close summary (snapshot for cold-start context)

Phase 7 closed at HEAD `60a4a67` (this handover update lands at
C6). 5/5 transition gate sections ☑:

1. **Functional**: 3-host green; `check_three_host_diff.sh` PASS.
2. **Debt-ledger**: 11 Active rows (was 14 before second sweep);
   D-009 + D-011 + D-017 closed inline at gate review per user
   direction「もうdebtから消せるな」.
3. **Design cleanliness**: AOT/GC/EH/WASI-p2/SIMD slots reserved;
   2 of 3 file-size hard-cap files split (cde3405); D-051 covers
   `x86_64/emit.zig` Phase 8 entry-task.
4. **§3a deferred-work DAG**: D-035/D-036/D-037/D-030 all closed;
   D-029 deferral rationale recorded in gate doc §5a.
5. **Strategic review**: ROADMAP §1+§2 read-back consistent;
   `meta_audit` produced `2026-05-08-phase7-close.md`; CI bench
   pulled forward (e3e6668); host-baseline ratios anchored in
   `history.yaml` per gate doc §5b.

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-050** WASI subset for JIT → §9.8 / 8.1 (NEXT; first Phase 8 task).
- **D-051** x86_64/emit.zig prologue extraction → §9.8 / 8.2 (ADR-grade).
- **D-022** ADR-0028 M3-a-2 trap event runtime write.
- **D-026** env-stub host-func wiring (cross-module dispatch).
- **D-029** parallel-move complete coverage (O-002 deferred per gate §5a).
- 詳細・全 11 Active rows は `.dev/debt.md` 参照。

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
