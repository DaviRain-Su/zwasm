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

## Cycles 26-28 progress (D-167 spike work-order step 1 COMPLETE)

**All 3 wrapper shapes Mac-green**: 1-arg+2-int (36 bytes;
cycle 26), 3-arg+2-int (44 bytes; cycle 27), 1-arg+3-int
MEMORY (22 bytes; cycle 28). `emitX8664Win64` predicate now
allows `n_params ∈ {0,1,3}` × (2-int register-class OR
1-arg-3-int MEMORY-class). All 4 D-167 entry-helper unique
shapes covered. Bytes per spike README § "Win64 byte
sequences (proven from cycle 21-24)". FILE-SIZE-EXEMPT
marker added (ADR-0099 D2 P1 — closed sub-language; tests
change in lockstep with emit).

**Wrapper extension only — entry.zig if-arm wire-up not yet
done.** Cycle 28 caveat: shape 3/3 wrapper is byte-correct
but runtime-correctness inherits the same body-side gating
issue as the existing 0-arg 3-int arm (cycle 2c MEMORY-class
body emit is `.sysv`-only today; bodies on Win64 use
register_write). Wire-up must coordinate both.

## Remaining work

### Autonomous-eligible (next session pick from here)

- **D-167 wire-up step 2** (spike work-order step 2) —
  synthetic end-to-end execution tests on Mac for each of
  the 3 shapes via hand-rolled body bytes (pattern at
  `wrapper_thunk.zig:579+` `() → (i32, i32, i32)`). Verifies
  the wrapper bridges register convention correctly under
  actual execution (Mac aarch64 path covers AAPCS64; x86_64
  SysV path covers ubuntu; Win64 path NOT runtime-verifiable
  on Mac/Linux — covered at step 4 windowsmini integration).
- **D-167 wire-up step 3** — entry.zig Win64 if-arms
  calling `invokeBufWin64Args` helper (add back in
  `entry_buffer_write.zig`). For 3-int MEMORY-class shape:
  ALSO needs body-side cycle 2c MEMORY-class extension to
  Win64 (currently `.sysv`-gated; see emit_setup.zig).
- **D-167 wire-up step 4** — windowsmini integration verify
  ESPECIALLY simd_assert (cycle 24's regression site).

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
