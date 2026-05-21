# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — §9.12-F D-055 closed

§9.12-F (debt active rows < 15) and §9.12-I (ADR canonical) open.

| Exit criterion                  | Latest fact                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| §9.12-F: debt active rows < 15  | 22 (D-055 closed this commit; was 23)                                       |
| §9.12-I: ADR `Accepted` < 30    | strict 33 / loose 52 — blocked on Phase 9 close                             |

**This commit (D-055 close — JIT-execution sentinel on x86_64
prologue)**:

The x86_64 prologue now emits the `MOV [R15 + jit_executed_flag_off],
1` sentinel (11 bytes, REX.B + 0xC7 + ModR/M + disp32 + imm32),
gated on `uses_runtime_ptr=true`. Mirrors the ARM64 inject at
`d6e29ac` per ADR-0034 (§9.8a / 8a.2).

- `src/engine/codegen/x86_64/emit.zig`: 1-line wire-up of
  `inst.encMovMemDisp32Imm32(.r15, jit_abi.jit_executed_flag_off,
  1)` inside the `if (uses_runtime_ptr)` branch, immediately
  after `MOV R15, runtime_ptr_save`.
- `src/engine/codegen/x86_64/prologue.zig`: `body_start_offset`
  helper now adds `sentinel_size = 11` to uses_runtime_ptr cases
  (was: noted in docstring as a deferred +N). Layout table
  updated to new offsets: 20 / 24 / 27 vs. 4 / 8 / 11.
- Final test-site fix-ups: `emit_test_int.zig` exp_prologue size
  13 → 24 + sentinel splice; total-length assertion 80 → 91.
- Final emit_test_float.zig site (unreachable JMP rel32)
  migrated to helper-relative.

Both test families (emit_test_int.zig + emit_test_float.zig)
substantially use `prologue.body_start_offset()` per ADR-0021 +
edge_case_testing.md; the +11 prologue shift propagates
automatically.

Behavior-preserving for all existing JIT-emit semantics; the
sentinel only adds a write to a previously-unused field
(`JitRuntime.jit_executed_flag`), which post-call readers can
inspect to confirm "JIT body actually ran" vs "compile-passed
but never invoked".

**Next pickup**: D-141 file-size cap WARN proliferation (18
files exceed 1000-LOC soft cap). Per ADR-0099 D2, each file
needs either (a) a per-file split ADR with P1-P4 conditions, or
(b) an EXEMPT marker for files in [2000, 2500] range. Approach
in batches.

## Recent context

- §9.12-G closed (`4bd62842`); §9.12-H closed (`600bd7cf`).
- §9.12-I batch 1 (`1095d225`) + batch 2 (`5e2b1a6e`).
- §9.12-F D-018 discharge (`02397144` + backfill `3df2f7ff`).
- §9.12-F barrier sweep (`d68ad87c`).
- D-055 migration batch 1 (`84c83e11`) + batch 2 (`b7d4f399`).

## Active `now` debts

- なし — D-055 closed.

## Other queued work

1. **D-141 per-file file-size ADRs** — 18 WARN files.
2. **§9.12-I revisit after Phase 9 close**.
3. **D-081 follow-up** — was blocked-by ADR-0054 amendment +
   ADR-0081 successor; needs re-walking now that D-055 closed
   (D-081 had a "paired with D-055" note).

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK.
- §9.12-F: 22 active rows; D-055 just closed; exit `< 15`.
- §9.12-G / §9.12-H: closed.
- §9.12-I: 29 ADRs flipped; blocked on Phase 9 close.

## Open questions / blockers

- なし for D-141 batches.

## See

- [ROADMAP](./ROADMAP.md) §9.12-F + §9.12-I scope + exit
- [`debt.md`](./debt.md), [`lessons/INDEX.md`](./lessons/INDEX.md)
- ADR-0034 (sentinel design), `d6e29ac` (ARM64 inject)
