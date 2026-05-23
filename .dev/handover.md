# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Fresh-session start here

**Authoritative remaining-work source**:
[`phase9_close_master.md`](./phase9_close_master.md)
§5.3a (Phase A + Phase B 2-stage iteration discipline).

**Mandatory before any §9.x [x] flip**:
`bash scripts/check_phase9_close_invariants.sh --gate`.

**Phase 9 close gate (mac-host)**: **18/18 PASS** (was 17/18
pre-cycle-20). I1 satisfied — no SKIP-WIN64-* emission.

**Test state**:
- Mac aarch64 `zig build test` / `test-all`: green.
- ubuntu test-all: green at HEAD=39eac7ba (verify next resume
  Step 0.7 for HEAD post-this-commit-pair).
- windowsmini test-all: simd_assert green (13351/0 fail);
  spec_assert_non_simd has D-167 1+arg multi-result fails
  (~10-11 directives across `break-br_if-num-num` /
  `break-br_table-num-num` / `break-br_table-nested-num-num` /
  `add64_u_with_carry`). NOT blocking Phase 9 close gate.

Closed 2026-05-23 cycles 10-25 summary (A1 D-157, A2 D-139,
A4 D-163/D-166 shared root-cause, Win64 2-i32-result fix,
ADR-0107 Proposed, cycle 21-24 D-167 revert): `git log
--grep="cycle 2[0-5]"` and `git log --grep="A1\|A2\|A4"`.

## Cycle 29 finding (D-167 wire-up blocked by entry.zig cap)

Attempted D-167 wire-up (3 Win64 if-arms in
`src/engine/codegen/shared/entry.zig`); pre-commit gate
emitted `EXEMPT-CAP EXCEEDED` (2521 vs cap 2500). File was
exactly at exempt-cap before edits. Compact 1-line
forwarding to a Win64-side helper module would still net
≥ 3 lines (one per if-arm). Reverted; filed **D-168** for
the structural split required before wire-up can land.

## Cycles 26-28 progress (D-167 spike step 1 COMPLETE)

3 wrapper shapes Mac-green: 1-arg+2-int (cycle 26),
3-arg+2-int (cycle 27), 1-arg+3-int MEMORY (cycle 28).
`emitX8664Win64` predicate covers all 4 entry-helper unique
shapes. Shape 3/3 inherits body-side `.sysv`-gating caveat
from existing 0-arg 3-int arm (separate cycle work). See
`git log --grep="D-167 shape"`.

## Remaining work

### Autonomous-eligible (next session pick from here)

- **D-168 entry.zig structural split** (filed cycle 29) —
  `src/engine/codegen/shared/entry.zig` is exactly at
  exempt-cap=2500. D-167 wire-up attempted cycle 29 added
  21 lines to that file (3 Win64 if-arms) and triggered
  `EXEMPT-CAP EXCEEDED` block. Even with compact 1-line
  forwarding to a Win64-side helper module (3 lines added),
  the cap is still exceeded. **D-167 wire-up is blocked
  until entry.zig is split.** Discharge path: see D-168 in
  debt.md for split strategy options.
- **D-167 wire-up shape 1-3** — blocked by D-168.
  After split: add `invokeBufWin64Args` helper +
  `entry.zig` Win64 if-arms for `callI32i32_i32` /
  `callI32i64_i32` / `callI64i32_i64i64i32`. Body-side
  cycle 2c MEMORY-class Win64 extension still required for
  shape 3/3 (`callI32i32i64_i32`).
- **D-167 windowsmini integration verify** — final step;
  blocked by all above.

### User-gated

- **A3 D-079 (ii)** — blocked-by: ADR-0107 Accept. Structural
  `Runtime.globals` byte-buffer migration (13 callsites + JIT
  codegen). ADR proposed; awaiting collab review.
- **§9.13 hard gate** — ADR-0105 + ADR-0106 `Status: Accepted`
  flip via Track D collab review + Phase B `[x]` re-flip with
  cited SHAs (per `phase9_close_master.md` §5.3a Phase B).

## Cold-start procedure

Per `/continue` SKILL.md Resume Steps 0.5 / 0.7 / 0.8. Lesson
scan: `2026-05-23-d163-d166-shared-root-cause.md` for Win64
multi-result context. D-167 is sole `now` row (sub-shape 2/3
next per "Remaining work" above).

## See

- [`phase9_close_master.md`](./phase9_close_master.md) §5.3a + §6.
- `private/spikes/d167-win64-multi-arg-wrapper/README.md`.
- ADR-0104 Revision 2026-05-23 (Phase 9 真スコープ).
- ADR-0107 Proposed (D-079 (ii) byte-buffer globals).

windowsmini SSH-reachable per ADR-0049. Debug infra:
`debug_jit_auto/SKILL.md` Recipes 15-17.
