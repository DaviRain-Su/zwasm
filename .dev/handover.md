# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — γ-5 landed (`552a2b6d` /
   `e902e531`). γ-3.d bisect this session refuted the
   "spectest table/memory/global gap" handover prediction:
   `imports/imports.1.wasm` has only `.func` imports. See
   [`lessons/2026-05-17-gamma3d-dispatch-write-segv-bisect.md`](lessons/2026-05-17-gamma3d-dispatch-write-segv-bisect.md).
   **Next = γ-3.d root-cause investigation** (dispatch-slot
   write triggers SEGV in subsequent vtable call; sigsetjmp
   arming does NOT recover — needs PAC / signal-delivery
   investigation; consider running on ubuntunote first to
   confirm Mac-aarch64 specificity).
2. `git log --oneline -10`. Latest: handover-only refresh.
   γ-5 `552a2b6d`. γ-4 DIAG `6b0d8ec4`. Prior β/γ chain via
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
  `table_init/table_init.1.wasm` crash.
- γ-3.d session this turn: bisect via `wasm-objdump -x` +
  per-step DIAG probes inside `resolveCrossModuleImports`.
  Refuted handover prediction (imports.1 has 0
  table/memory/global imports — all 18 imports are `.func`).
  Localised the SEGV to the heap write
  `new_dispatch[i] = @intFromPtr(slot.ptr)`. The subsequent
  vtable call `callbacks.on_module_loaded(...)` SEGVs before
  the function body runs; `sigsetjmp` arm around the call
  does NOT recover (handler takes unarmed branch). Full
  evidence in [`lessons/.../gamma3d-dispatch-write-segv-bisect.md`](lessons/2026-05-17-gamma3d-dispatch-write-segv-bisect.md).
- **γ-3.d NEXT**: run probe on ubuntunote to confirm/refute
  Mac-aarch64 specificity, then investigate PAC / signal-
  delivery race per the lesson's hypotheses §.
- `src/engine/runner.zig` is at 1996 / 2000 LOC — split
  before next γ landing (cross-module patch helpers / table
  init family extraction).
- (c)-2.4 (distiller) follows once γ resolution lands.

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
