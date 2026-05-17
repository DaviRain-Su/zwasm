# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — chunks α (ABI shape) + β (arm64 mirror)
   landed. Chunk γ (x86_64 mirror + γ-4 permanent relax) next.
2. **READ NEXT** [`.dev/decisions/0068_dual_view_table_storage_fix.md`](decisions/0068_dual_view_table_storage_fix.md)
   §A4 chunk γ. Auto-loaded:
   [`.claude/rules/dual_view_table_sync.md`](../.claude/rules/dual_view_table_sync.md).
3. `git log --oneline -10`. Latest: chunk β (arm64) — all 5
   contract fixtures green on Mac. Prior chain via
   `git log --grep="9.9-III"`.
4. `bash scripts/p9_simd_status.sh` — live SIMD via ubuntunote.
5. `cat .dev/debt.md | head -90`. D-126 row body has the
   3-chunk plan summary.

## Active state — Phase 9 close-plan Step (c) D-126 chunk γ

Chunks α + β complete:
- α: `FuncEntity.funcptr` field; `TableSlice` 16→24 bytes
  (added `funcptrs: [*]allowzero u64`); stride references in
  arm64+x86_64 op_table/op_call re-derived through
  `jit_abi.table_slice_size`; setup wiring + null sentinel
  for externref tables.
- β: arm64 emit `mirrorWrite*` for `emitTableSet` / `Fill` /
  `Init` / `Copy` (+typeidx mirror for cross-table copy);
  `growableTableGrowFn` mirrors host-side. All 5 fixtures
  PASS on Mac aarch64.

Mac chunk β gate: `zig build test-all` EXIT=0;
`test-edge-cases` 51 PASS; spec_assert_runner_non_simd
24034/0/2015 unchanged.

### Next-session active task — D-126 chunk γ (x86_64 mirror + γ-4)

Per ADR-0068 §A4 chunk γ scope:

- Wire the arm64 chunk β logic into `x86_64/op_table.zig` for
  the same 5 op handlers (`emitTableSet` / `Fill` / `Init` /
  `Copy` (+typeidx mirror) / `Grow` via host-side covered).
- x86_64 register conventions differ: use SysV/Win64 scratch
  regs (RAX/RCX/RDX/R8..R11 free in the op-handler scope).
- Add a CBZ-equivalent skip on `funcptrs_base == 0` (use
  `TEST + JZ` on x86_64).
- Land the **γ-4 permanent relax**: re-enable
  `hasUnbindableImports` short-circuit (removed during D-142
  bisect). Cross-module table_copy / table_init / ref_func /
  imports fixtures should green up across the 113 functional
  FAILs once the x86_64 mirror lands AND γ-4 is restored.
- Capture optional bench delta per §A5 in commit body
  (informational baseline for Phase 15 perf restore).

### Discipline reminders

Pre-commit hook active (`gate_commit.sh`); no `--no-verify`
per §14. 2-host gate per chunk (Mac + ubuntunote);
windowsmini batch at Phase 9 close.

### Outstanding `now` debts

D-079(v128 cross-module → (c)-2.4 sub-gap ii); **D-126
(IN PROGRESS — α/β landed, γ next)**; D-133(arm64 op_table
scratch sweep). D-016 + D-052 + D-138 + D-142 + D-143 CLOSED.

`blocked-by` rides: D-103/D-105 → (c)-2.3/2.4; D-079(ii) →
(c)-2.4; D-136 → step (d) Win64 SEH; D-135 entry.zig
comptime; D-094/D-137/D-140 multi-result ABI bridge family.

## Sandbox + References

`~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
Per-chunk 2-host (Mac + ubuntunote); windowsmini Phase-
boundary batch.

PRIMARY: [`phase9_close_plan.md`](phase9_close_plan.md).
ADRs: [`0065`](decisions/0065_wasm_1_0_instance_work_phase9_rescope.md)
/ [`0066`](decisions/0066_cross_module_import_bridge_thunks.md)
/ [`0067`](decisions/0067_ubuntunote_native_x86_64_gate_host.md)
/ **[`0068`](decisions/0068_dual_view_table_storage_fix.md)**.
Auto-loaded rules: [`dual_view_table_sync.md`](../.claude/rules/dual_view_table_sync.md).
