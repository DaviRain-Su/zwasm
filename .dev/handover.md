# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — (c)-1/(c)-2.0/(c)-2.1/(c)-2.2 landed;
   (c)-2.3-α/β-1/β-2a/β-2b/γ-1/γ-2 landed; **next = (c)-2.3-γ-3
   per-exporter table state (funcptrs / typeidxs / multi-table)**.
2. `git log --oneline -10`. Latest: `413d9b57` (c)-2.3-γ-2
   per-exporter `scratch_memory` + `EXPORTER_MEMORY_CAPACITY`.
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

### Next-session active task — (c)-2.3-γ-3 per-exporter table

Read `private/notes/p9-9.9-III-c-2.3-gamma-survey.md` FIRST
(corpus taxonomy + 5-step γ-1..γ-5 ramp). The static-scratch
isolation finding from the β survey still applies for
funcptrs / typeidxs / multi-table descriptors.

Sub-chunking progress (Cat III (c)-2.3):
- α/β-1/β-2a/β-2b/γ-1/γ-2 — see `git log --grep="9.9-III"`.
- β-2b: W^X gap fixed in `allocArena` (lesson
  `2026-05-17-mac-aarch64-thread-rx-mode-survives-alloc`).
- γ-1 `9518eb4d`: `RegisteredExporter.scratch_globals` +
  `applyDefinedGlobalsInit` + `rt.globals_base` wiring + unit
  test.
- γ-2 `413d9b57`: `RegisteredExporter.scratch_memory` +
  `applyActiveDataSegments` + `rt.vm_base` / `rt.mem_limit`
  wiring + `EXPORTER_MEMORY_CAPACITY = 1 MiB` cap + unit test.
- **γ-3 NEXT**: per-exporter table state. Add
  `scratch_funcptrs: ?[]u64` + `scratch_typeidxs: ?[]u32` +
  per-exporter multi-table descriptor + jit_ci scratch.
  Populate via `applyTableInit` + `setupMultiTableScratch`
  against the exporter's wasm bytes; wire `rt.funcptr_base` /
  `rt.typeidx_base` / `rt.table_size` / `rt.tables_ptr` /
  `rt.tables_jit_ci_ptr`. ~150 LOC per γ-survey §γ-3. Unit test
  with a `(module (table 1 funcref) (elem (i32.const 0) 0)
  (func ...))` payload.
- γ-4 / γ-5 LATER: relax `hasUnbindableImports` (β-2b code
  already takes the param via `_ = registered;`); module-
  qualified invoke directive. See γ-survey for ramp.

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
