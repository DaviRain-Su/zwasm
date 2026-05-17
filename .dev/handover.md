# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — D-142 fix (A) chain complete; γ-4
   probe behaviorally verified the thunks; D-126 chunk α
   landed (ABI shape + helper skeleton + 5 contract fixtures
   failing at gate). Chunks β (arm64) / γ (x86_64) next.
2. **READ NEXT** [`.dev/decisions/0068_dual_view_table_storage_fix.md`](decisions/0068_dual_view_table_storage_fix.md)
   §A4 — chunk β wires `mirrorWrite` into the 4 arm64 op
   handlers (emitTableCopy / emitTableInit / emitTableSet /
   emitTableGrow; emitTableFill bundled). Auto-loaded:
   [`.claude/rules/dual_view_table_sync.md`](../.claude/rules/dual_view_table_sync.md).
3. `git log --oneline -10`. Latest: chunk α ABI shape +
   `shared/table_storage.zig` skeleton. Prior chain via
   `git log --grep="9.9-III"`.
4. `bash scripts/p9_simd_status.sh` — live SIMD via ubuntunote
   native x86_64 (ADR-0067).
5. `cat .dev/debt.md | head -90`. D-126 row body has the
   3-chunk plan summary.

## Active state — Phase 9 close-plan Step (c) D-126 chunk β

Chunk α complete:
- `FuncEntity.funcptr: usize` field added; populated at
  every construction site (production runner, spec_assert
  scratch, interp instantiate, test stubs).
- `TableSlice` extended 16 → 24 bytes (added `funcptrs:
  [*]u64`); stride references in arm64+x86_64 `op_table.zig`
  / `op_call.zig` re-derived via `jit_abi.table_slice_size`;
  `tableidx` cap lowered 1024 → 512 to preserve W-form
  imm12 budget.
- `shared/table_storage.zig` skeleton landed with
  `mirrorWriteOne` / `mirrorWriteRange` empty stubs.
- Setup wired: `tables_descriptors[k].funcptrs` aliases
  `funcptrs_buf` (k=0) / `extra_funcptrs_buf[off..]` (k>0)
  in both production `setupRuntime` and spec_runner
  `setupMultiTableScratch`.
- 5 contract WAT fixtures under
  `test/edge_cases/p9/table_storage_sync/` — copy_then_call,
  set_then_call, init_then_call, fill_then_call, copy_cross.
  All 5 FAIL at chunk-α gate (mirror helper body empty);
  chunk β/γ greens them.

2-host gate (Mac + ubuntunote) at chunk α: `zig build
test-all` EXIT=0 on both; `zig build test-edge-cases`
shows 46/5 (existing 46 PASS + 5 new contract fixtures
FAIL as expected).

### Next-session active task — D-126 chunk β (arm64 4-op mirror)

Per ADR-0068 §A4 chunk β scope:

- Wire `shared/table_storage.zig::mirrorWriteOne` /
  `mirrorWriteRange` bodies for arm64. Helper emits paired
  STR pairs covering `refs` view and `funcptrs` view at
  the same dst index; reads source funcptr via
  `FuncEntity.funcptr` for `emitTableSet`, via
  `tables_ptr[src_tbl].funcptrs[src]` for `emitTableCopy`,
  via `ElemSlice` for `emitTableInit`, via `init` operand's
  derived funcptr for `emitTableGrow` / `emitTableFill`.
- Re-route the 4 (5 incl. fill) arm64 op handlers in
  `op_table.zig` to call `mirrorWrite*` instead of the
  current single-STR-to-refs sequence. Per
  `.claude/rules/dual_view_table_sync.md` discipline.
- Fixtures green on Mac; ubuntunote stays red (x86_64
  mirror pending → chunk γ).

### Subsequent chunk γ

- x86_64 mirror + `hasUnbindableImports` permanent relax
  (γ-4 land). Both hosts green at 0 FAIL.
- Capture optional bench delta (§A5) into commit body.

### Discipline reminders

Pre-commit hook active (`gate_commit.sh`); no `--no-verify`
per §14. 2-host gate per chunk (Mac + ubuntunote);
windowsmini batch at Phase 9 close.

### Outstanding `now` debts

D-079(v128 cross-module → (c)-2.4 sub-gap ii); **D-126
(IN PROGRESS — chunk α landed, chunk β next)**; D-133
(arm64 op_table scratch sweep). D-016 + D-052 + D-138 +
D-142 + D-143 CLOSED.

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
