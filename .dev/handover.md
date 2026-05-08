# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — D-054 `blocked-by:` reframed (separate from D-053);
   D-055 + 9 other rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/decisions/0031_zir_hoist_pass.md` (ADR-0031 hoist; needs amend
   after D-053 close).

## Current state — Phase 8 / §9.8a / 8a.6 (boundary audit)

§9.8a / 8a.5 closed: D-053 hoist branch_targets-as-PC bug
fixed at `2e0022c`. Cap removed; baseline preserved (52/55
compile-pass + 15 RUN-JIT-VERIFIED on Mac aarch64).

直近 commits (latest at top):

- (this commit) chore(p8): mark §9.8a / 8a.5 [x]; D-053 closed;
  D-054 reframed as independent OrbStack-only investigation.
- `2e0022c` (rebased to `34a3ac1`) fix(p8): §9.8a / 8a.5-c/d —
  hoist branch_targets-as-PC bug; remove cap.
- `b204ad3` feat(p8): §9.8a / 8a.5-b — diagnostic errdefer in
  arm64/emit op-dispatch; localised regression to br_table.
- `f212892` chore(p8): §9.8a / 8a.5-a cap-removed reproducer
  findings.

3-host gate at `34a3ac1` (post-D-053 fix): Mac green; OrbStack
1 known D-054 FAIL (unchanged from pre-fix; same 0xFD1BD386 →
D-054 has separate root cause); windowsmini green (212/0/20).

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; 8a.1-8a.5 [x]; **§9.8a /
8a.6 NEXT** (8a boundary audit). Phase 8 残 rows = 8a.6 +
8b.1-8b.6.

## Active task — §9.8a / 8a.6: 8a boundary audit **NEXT**

Per ROADMAP row text:
> Phase-8a boundary `audit_scaffolding` pass — focuses on §A
> (functional health) + §F (debt coherence after D-053
> discharge) + §G (extended challenge anchors with the new
> diag infra).

This is a meta-pass invoking the `audit_scaffolding` skill in
"phase boundary" mode. Then close 8a, advance to 8b.

D-053 closure note: the actual root cause was NOT in the emit
pass (the 8a.5 row's hypothesis was "ZirOp emit handler under
post-hoist IR"). The bug was upstream in `hoist/pass.zig`:
`branch_targets[]` entries were being PC-shifted as if they
were PCs, but they're Wasm br/br_table block-stack depths.
At cap=4, depth values (0/1/2 typically) plus small shifts
landed by coincidence on valid block-stack indices. At cap >
~10-20, depth shift inflated past `labels.items.len`,
triggering `arm64/op_control.zig:240` UnsupportedOp on
br_table.

Lesson candidate: `2026-05-09-hoist-branch-targets-as-pc.md`
("a single-axis-mistake hidden by a small-input mask"). The
existing test "shifts branch_targets across hoist prologue"
locked in the wrong semantics; rewriting it as "leaves
depths invariant" exposes the lock-in failure mode worth
codifying.

D-054 reframe (debt.md updated this commit): the OrbStack-only
as-loop-broke regression is **NOT** caused by the hoist
branch_targets bug. Same 0xFD1BD386 value pre/post D-053 fix.
Independent root cause; hypothesis: OrbStack/Rosetta x86_64
emulation interaction OR a Linux-x86_64-only path skirted by
Win64 ABI on windowsmini. Investigation deferred; D-054 stays
`blocked-by:` with updated barrier.

Suggested chunk plan:

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8a.6-a | Run audit_scaffolding skill in phase-boundary mode       | **NEXT** |
| 8a.6-b | Apply any local-fix `block` findings inline              | [ ]      |
| 8a.6-c | Add lesson `2026-05-09-hoist-branch-targets-as-pc.md`    | [ ]      |
| 8a.6-d | Amend ADR-0031 Revision history with D-053 root-cause note | [ ]    |
| 8a.6-e | SHA-backfill §9.8a rows; mark 8a.6 [x]; open §9.8b        | [ ]      |

After 8a.6 closes: §9.8b begins (Coalescer / Regalloc upgrade /
AOT skeleton). Step 5b's `8a.1+8a.2+8a.3 all [x]` trigger now
satisfied — Phase 8b chunks will be bench-delta-gated.

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-054** (`blocked-by: separate investigation; OrbStack-only`)
  — reframed; separate from D-053.
- **D-055** (`blocked-by: D-052 + emit_test_*.zig migration`) —
  x86_64 prologue inject deferred.
- 9 `blocked-by:` rows — D-007 / D-010 / D-016 / D-018 / D-020
  / D-021 / D-022 / D-026 / D-028 / D-052; barriers all hold.

D-053 closed at `2e0022c` (was promoted to ROADMAP row §9.8a /
8a.5).

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
