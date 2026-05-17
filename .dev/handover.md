# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — through γ-3.b-ii landed; γ-4 DIAG
   handler (`6b0d8ec4`) identified crash at
   `table_init/table_init.1.wasm`. Root cause: importer's
   element segments leave funcptr=0 for imported funcs in
   tables → `call_indirect` BLRs 0. **Next = γ-5 import-in-
   table thunk patch** (post-`applyTableInit` hook in the spec
   runner that substitutes `current_dispatch[N]` thunk addrs
   for entries with fidx < num_imports).
2. `git log --oneline -10`. Latest: `6b0d8ec4` γ-4 DIAG
   handler trace. γ-3.b-ii `84f62398`, γ-3.b-i `3b003b9e`.
   Prior β/γ chain via `git log --grep="9.9-III"`.
3. `bash scripts/p9_simd_status.sh` — live SIMD via ubuntunote
   native x86_64 (ADR-0067).
4. `cat .dev/debt.md | head -90`. Cat III sub-chunks tracked
   in close-plan §6 step (c), not granular ROADMAP rows.

## Active state — Phase 9 close-plan Step (c)-2.3

D-134 closed structurally (Rosetta race; ubuntunote native
host eliminates). Cat III JIT dispatch infra: registry
(c)-1a/b/c; ADR-0066 design (c)-2.0; arm64 32-byte /
x86_64 22-byte opcode-pinned thunk encoders (c)-2.1;
`shared/thunk.zig` arena lifecycle (c)-2.2; resolver substrate
+ wire-up (c)-2.3-α/β-1/β-2a/β-2b. Counts unchanged with
γ-relaxation deferred: 24034/0/2015 + 13301/0/440 + 212/0/20
Mac+ubuntunote bit-identical (β-2b kept hasUnbindableImports
strict — exercising the dispatch+arena infra via spectest-
import modules, but pre-existing cross-module fixtures still
SKIP-CROSS-MODULE-IMPORTS until γ lands per-exporter backing).

### Next-session active task — (c)-2.3-γ-3.b remaining state

Read `private/notes/p9-9.9-III-c-2.3-gamma-survey.md` FIRST
(corpus taxonomy + 5-step ramp; γ-3.b note appended below).

Sub-chunking progress (Cat III (c)-2.3):
- SHAs through γ-4 DIAG: `git log --grep="9.9-III"`.
- γ-4 DIAG `6b0d8ec4`: in-handler `last_module_name` trace
  surfaces SEGV-fixture before `_exit(142)`. Permanent
  infrastructure for future γ-4 retries.
- γ-4 DIAG run finding: SEGV at
  `table_init/table_init.1.wasm`. Importer's element segments
  place imported funcs (a.ef0..a.ef4) into tables; for
  funcidx < num_imports, `applyTableInitForTable`
  (`src/engine/runner.zig` ~line 1127) `continue`s without
  writing funcptr (leaves it 0). `call_indirect` BLRs 0 →
  SEGV. Verdict: the gap is NOT `RegisteredExporter` state-
  backing — it's import-in-table dispatch.
- **γ-5 NEXT**: in the spec runner, after `applyTableInit` /
  `setupMultiTableScratch`, patch the importer's funcptr
  table entries whose corresponding source funcidx is an
  import — substitute the resolved thunk address from
  `current_dispatch[N]` (which β-2b's resolver wrote). Run γ-4
  retry afterward; the DIAG trace will identify the next
  gap if any remains.
- γ-3.c (per-exporter multi-table) + (c)-2.4 (distiller)
  follow once γ-4 lands.

(c)-2.4 = corpus distiller's `supported` set extension + new
fixture rebuild; discharges D-138 fully + D-079 sub-gap ii.

### Discipline reminders

Pre-commit hook active (`gate_commit.sh`); no `--no-verify`
per §14. 2-host gate per chunk: Mac foreground +
`bash scripts/run_remote_ubuntu.sh test-all > /tmp/ubuntu.log 2>&1`
background. D-134 closed; future heisenbugs use 5-streak +
3-SHA rule.

### Outstanding `now` debts (5)

D-016(applySanitize wrapper); D-052(x86_64 prologue extract);
D-079(v128 cross-module → (c)-2.4); D-126(bulk.wast post-
mutation per ADR-0065); D-133(arm64 op_table scratch sweep).

`blocked-by` rides (corresponding chunks):
D-103/D-105 → (c)-2.3/2.4; D-138 → (c)-2.4;
D-136 → step (d) Win64 SEH; D-135 entry.zig comptime;
D-094/D-137/D-140 multi-result ABI bridge family.

## Sandbox + References

`~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
Per-chunk 2-host (Mac + ubuntunote); windowsmini Phase-
boundary batch.

PRIMARY: [`phase9_close_plan.md`](phase9_close_plan.md).
ADRs: [`0065`](decisions/0065_wasm_1_0_instance_work_phase9_rescope.md)
/ [`0066`](decisions/0066_cross_module_import_bridge_thunks.md)
/ [`0067`](decisions/0067_ubuntunote_native_x86_64_gate_host.md).
[`ubuntunote_setup.md`](ubuntunote_setup.md) ·
[`lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md`](lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md).
