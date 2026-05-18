# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6 Step (e) — Phase 9 close sequence. Step (b) Cat II + (c)
   Cat III + (d) Cat IV-relocation all DONE; only Step (e) tasks
   remain before §9.9 row flips `[x]`.
2. `git log --oneline -10`. Latest:
   `fb063b09 chore(p9): D-148 → blocked-by upstream; workaround
   landed, 2-host bit-identical at 25325/0/688`.
3. `bash scripts/p9_simd_status.sh` — live status (SIMD 13301/0/440
   bit-identical Mac + ubuntunote; non-simd 25325/0/688 bit-identical).
4. `cat .dev/debt.md`. `now`: D-079, D-133 (both blocked-by §9.12
   audit cleanup).

## Active state — §9.9 [x] flip ready; Cat I+II+III all closed

- Cat I (SIMD): 13301/0/440 bit-identical (D-145 cycle 10 close).
- Cat II (multi-result entry helpers): drained. `skip-impl
  multi-result` count = 0. Last gap was D-140 large-sig
  (17 params / 16 mixed Class C results); closed via
  ADR-0026 Convention Swap + arm64 Apple natural-size stack
  packing + LLVM-backend workaround for one upstream Zig bug.
- Cat III (Wasm 1.0 instance / cross-module / host imports /
  start-trap): DONE 2026-05-18 (cycle 5, commit `2dbd3f15`).
- Cat IV (windowsmini SEH bridge + reconcile): relocated to
  §9.13-0 per ADR-0049 + ADR-0056 + ADR-0065 (2026-05-18).

## Outstanding upstream blocker

D-148 (Zig 0.16 self-hosted x86_64 Debug backend miscompile for
`callconv(.c)` 9-FP-scalar + MEMORY-class return) is filed at
[Codeberg ziglang/zig#35343](https://codeberg.org/ziglang/zig/issues/35343).
Workaround in `build.zig` (`.use_llvm = true` on the non-simd
spec_assert runner exe; commit `a8474d1a`); minimal Zig-only
repro at `private/spikes/d148-zig-sysv-fp-args/`. Removal
condition: upstream fix lands → drop the override.

## Next-session active task — §9.9 close per close-plan Step (e)

Execute Step (e) of [`phase9_close_plan.md`](phase9_close_plan.md):

1. `audit_scaffolding` invocation (Phase 9 boundary mandatory).
2. SHA backfill for §9.9 sub-task rows.
3. Flip ROADMAP §9.9 row `[ ]` → `[x]`.
4. Phase Status widget: leave Phase 9 as IN-PROGRESS (clears on
   §9.13 [x] per close plan Step (g)).
5. **HARD GATE STOP**: per `.claude/skills/continue/SKILL.md`
   §"Exception — hard human-in-loop transition gates", the loop
   detects §9.12 (`🔒` + `phase9_completion_substrate_audit.md`)
   as the next `[ ]` row, skips `ScheduleWakeup`, and surfaces a
   one-sentence handoff for collaborative review.

Substrate audit doc reachable at
[`phase9_completion_substrate_audit.md`](phase9_completion_substrate_audit.md);
filed per ADR-0062 to decide §2 P13/P14 + §4.5/§4.6 alignment
(DispatchTable completion vs comptime-switch vs hybrid) BEFORE
Phase 10 features land.

### Discipline reminders

No `--no-verify`. 2-host per chunk (Mac + ubuntunote);
windowsmini reconcile stays at §9.13-0 (post-§9.12).

### Outstanding `now` debts

- D-079: v128 cross-module imports (blocked-by §9.12 audit
  cleanup cohort).
- D-133: arm64 op_table / op_memory hardcoded X10/X11/X12
  scratch sweep (blocked-by §9.12 audit cleanup cohort).
- D-148: blocked-by upstream Zig fix; workaround in place.
- §9.13-0 cohort: D-084 / D-028 / D-136 (windowsmini SEH).

## Sandbox + References

`~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
Per-chunk 2-host; windowsmini at §9.13-0.

PRIMARY: [`phase9_close_plan.md`](phase9_close_plan.md) §6 Step
(e). Hard gate target:
[`phase9_completion_substrate_audit.md`](phase9_completion_substrate_audit.md).
ADRs: [`0062`](decisions/0062_phase9_completion_substrate_audit.md)
(gate doc anchor), [`0026`](decisions/0026_x86_64_runtime_invariant_strategy.md)
(Convention Swap), [`0069`](decisions/0069_multi_result_return_abi.md)
(multi-result ABI).
Lessons: [`2026-05-18-apple-arm64-natural-packing.md`](lessons/2026-05-18-apple-arm64-natural-packing.md);
[`2026-05-18-parallel-move-cycle-in-if-merge.md`](lessons/2026-05-18-parallel-move-cycle-in-if-merge.md).
