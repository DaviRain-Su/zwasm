# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — γ-5 landed (`552a2b6d` /
   `e902e531`). γ-4 DIAG with γ-5 advanced from
   `table_init/table_init.1.wasm` to
   `imports/imports.1.wasm` — different gap. **Next = γ-3.d**
   (spectest table/memory/global imports — separate from
   func-import bridges).
2. `git log --oneline -10`. Latest: `552a2b6d` γ-5 import
   funcptr patch. γ-4 DIAG `6b0d8ec4`. γ-3.b-ii `84f62398`,
   γ-3.b-i `3b003b9e`. Prior β/γ chain via
   `git log --grep="9.9-III"`.
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
- SHAs through γ-5: `git log --grep="9.9-III"`.
- γ-5 `552a2b6d`: `runner_mod.patchTableImportFuncptrs` helper +
  wire into nonSimd/simd on_module_loaded, assert_uninstantiable,
  and `setupMultiTableScratch` (multi-table). Resolves the
  `table_init/table_init.1.wasm` crash (the prior γ-4 DIAG
  fixture).
- γ-4 DIAG retry post-γ-5 advanced past table_init to
  `imports/imports.1.wasm`. Different gap: importer with
  spectest table/memory/global imports — currently
  hasUnbindableImports trips on `.table/.memory/.global =>
  return true`. Likely a subsequent fixture that does compile
  + runs into another unbacked path; bisect needed.
- **γ-3.d NEXT**: investigate post-γ-5 `imports/imports.1`
  SEGV — likely spectest table/memory/global binding gap or
  another unbacked field. Re-run γ-4 DIAG to pinpoint.
- `src/engine/runner.zig` is at 1996 / 2000 LOC — split
  before next addition (cross-module patch helpers / table
  init family extraction).
- (c)-2.4 (distiller) follows once γ-4 lands.

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
