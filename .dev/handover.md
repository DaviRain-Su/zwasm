# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — D-054 + D-055 + 9 other rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: hoist-branch-targets-as-pc, regalloc, coalescer).
5. `.dev/decisions/0031_zir_hoist_pass.md` (D-053 root-cause amend per 8a.6).
6. `.dev/optimisation_log.md` (F/R/O ledger; 8b adoption discipline).

## Current state — Phase 8 / §9.8b / 8b.1-c (Coalescer pass implementation)

§9.8a closed across 6 commits (a/b/c/d/e/f rows). Lesson
`2026-05-09-hoist-branch-targets-as-pc.md` + ADR-0031 D-053-
discharge Revision row landed this commit. SHA backfill for
§9.8a rows. **Phase 8a foundation complete.**

直近 commits (latest at top):

- (this commit) chore(p8): close §9.8a — lesson + ADR-0031
  amend + SHA-backfill + retarget at §9.8b.
- `b2b47f8` chore(p8): mark §9.8a / 8a.5 [x]; reframe D-054 as
  independent.
- `2e0022c` (rebased `34a3ac1`) fix(p8): §9.8a / 8a.5-c/d —
  hoist branch_targets-as-PC bug; remove cap.

3-host gate at `34a3ac1` post-D-053-fix: Mac green, OrbStack
1 known D-054 FAIL only, windowsmini green.

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; **§9.8a complete**
(8a.1-8a.6 [x]); **§9.8b / 8b.1 NEXT** — Phase 8 残 rows =
8b.1 + 8b.2 + 8b.3 + 8b.4 + 8b.5 + 8b.6.

Step 5b's `8a.1+8a.2+8a.3 all [x]` trigger satisfied — Phase
8b chunks will be **bench-delta-gated** per ADR-0032.

## Active task — §9.8b / 8b.1-c: Coalescer pass implementation **NEXT**

8b.1-b complete: ADR-0035 landed at
`.dev/decisions/0035_coalescer_pass.md`. Decision: post-
regalloc slot-aliasing metadata-only pass at
`src/ir/coalesce/pass.zig` (Zone 1, mirrors
`src/ir/hoist/pass.zig` shape). No IR mutation; populates
`func.coalesced_movs: ?[]CoalesceRecord` (already-
reserved slot per ROADMAP §P13). Emit pass queries
metadata before each MOV emission and skips redundant
slots. Arch-blind (no per-arch logic per A12).

8b.1-c plan:
- Implement `src/ir/coalesce/pass.zig` with `pub fn run(
  allocator, func, alloc) Error!void` shape.
- `CoalesceRecord` struct (already declared in `src/ir/
  zir.zig` as Phase 15+ slot).
- `isCoalesceCandidate` op catalogue (start with
  `local.tee` post-regalloc + return-value marshalling
  + select; grow as bench-delta surfaces wins).
- Bail logic: branch targets, call sites, across-call
  spill-timing (per W54 lesson).
- 3 unit tests: same-slot detection / call-site bail /
  branch-target bail.

## Active task (historical) — §9.8b / 8b.1-b ADR-0035 design

8b.1-a survey complete (private/notes/p8-8b1-coalescer-survey.md;
155 lines). Headline:

- v1 had a coalescer attempt (`ec8182f` archived) that passed
  Mac aarch64 but failed x86_64 `go_math_big` due to emit-stage
  spill-timing assumptions. Lesson: liveness must be const
  input to regalloc; post-regalloc IR shape can't assume
  per-arch details.
- cranelift delegates coalescing to regalloc2 entirely.
  regalloc2 itself coalesces DURING allocation via
  `ParallelMoves<T>`.
- winch + wasmer singlepass: no dedicated coalescer pass —
  validates that single-pass JIT can't afford multi-pass
  analysis.

**MVP recommendation: option (b) post-regalloc slot-aliasing**
(per ROADMAP row text). 1-2 day scope. Single-pass scan after
regalloc; detect `src_slot == dst_slot` MOVs where dst isn't
re-used; emit-time skip via `redundant_movs` metadata table.

Three divergences from upstream:
1. No in-IR coalescing (vs regalloc2): liveness is const input;
   coalescing as metadata discovery, not IR mutation.
2. No scratch-register cycle insertion: greedy-local regalloc +
   deterministic slot assignment means no same-slot cycles.
3. Branch-target bail: option (b) conservatively bails on
   forward branches (W54-class lesson). Dominance-aware Phase 15.

Bench candidates (highest SNR for coalescer wins):
- ★★★ tinygo/fib_loop.wasm (15-25% expected)
- ★★★ shootout/nestedloop.wasm (10-20%)
- ★★ tinygo/string_ops.wasm (8-12%)
- ★★ shootout/sieve.wasm (5-10%)

Suggested chunk plan (continuing 8b.1):

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8b.1-a | Step 0 survey (subagent: Explore)                        | [x] (this commit; survey at `private/notes/p8-8b1-coalescer-survey.md`) |
| 8b.1-b | ADR `0035_coalescer_pass.md` design framing               | **NEXT** |
| 8b.1-c | Implement post-regalloc slot-aliasing pass (`src/ir/coalesce/pass.zig`) + unit tests | [ ]      |
| 8b.1-d | Wire into `compile.zig` pipeline; bench-delta capture     | [ ]      |
| 8b.1-e | 3-host gate; close 8b.1 [x] with bench-delta in commit body | [ ]      |

After 8b.1: 8b.2 (Regalloc upgrade), 8b.3 (AOT skeleton),
8b.4 (≥10% aggregate), 8b.5 (Phase 8 boundary audit), 8b.6
(open §9.9).

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-054** (`blocked-by: separate investigation`) — OrbStack-
  only; independent of D-053. Likely Rosetta JIT-emulation
  interaction or Linux-x86_64-only path.
- **D-055** (`blocked-by: D-052 + emit_test_*.zig migration`) —
  x86_64 prologue inject deferred (sentinel ARM64-only).
- 9 `blocked-by:` rows — D-007 / D-010 / D-016 / D-018 / D-020
  / D-021 / D-022 / D-026 / D-028 / D-052; barriers all hold.

D-053 closed at `2e0022c` (was promoted to ROADMAP row §9.8a /
8a.5).

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
