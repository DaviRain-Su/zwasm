# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — (c)-1/(c)-2.0/(c)-2.1/(c)-2.2 landed;
   **next = (c)-2.3 resolver wire-up**.
2. `git log --oneline -15`. 2026-05-17 batch:
   `58e69207` Ubuntu pivot + D-134 closure (ADR-0067) →
   `bdb47eb9` review fix-ups → `ab973f56` (c)-2.2 thunk arena →
   `3c13c65c` D-016 close → `3b1a4301` entryAddr accessor →
   `cf8c25f7` thunk re-export + survey detail → `4a805856`
   (c)-2.3-α `RegisteredExporter` struct + map shape.
3. `bash scripts/p9_simd_status.sh` — live SIMD via ubuntunote
   native x86_64 (ADR-0067).
4. `cat .dev/debt.md | head -90`. D-016 newly flipped `now`
   2026-05-17 (build.zig > 600 LOC).
5. Cat III sub-chunks tracked in close-plan §6 step (c), not
   granular ROADMAP rows.

## Active state — Phase 9 close-plan Step (c)-2.3

D-134 closed structurally (Rosetta race; ubuntunote native
host eliminates). Cat III JIT dispatch infra: registry
(c)-1a/b/c; ADR-0066 design (c)-2.0; arm64 32-byte /
x86_64 22-byte opcode-pinned thunk encoders (c)-2.1;
`shared/thunk.zig` arena lifecycle (c)-2.2. Counts unchanged
(arena uncalled until resolver): 24034/0/2015 + 13301/0/440
+ 212/0/20 Mac+ubuntunote bit-identical.

### Next-session active task — (c)-2.3-β resolver minimal

Read `private/notes/p9-9.9-III-c-2.3-resolver-survey.md`
FIRST. Two architecture findings recorded:
1. `makeJitRuntime` static `host_dispatch_stubs` requires
   option (B) per-module dispatch override.
2. Static-scratch (`growable_memory`, `scratch_globals`,
   `scratch_funcptrs`, `scratch_func_entities` etc.) means
   per-module STATE isolation also needed for any cross-
   module callee that touches memory / globals / tables.

Revised sub-chunking:
- **(c)-2.3-α DONE** (`4a805856`): RegisteredExporter struct +
  map shape, behavior-neutral.
- **(c)-2.3-β NEXT**: minimal resolver supporting cross-module
  func calls where the callee touches NO memory / globals /
  tables / further imports. Static-scratch preserved; only
  per-fixture dispatch override. Use `runner_mod.findExportFunc`
  + `JitModule.entryAddr` + `shared.thunk.{allocArena,emitThunk,
  thunkSlot,finalizeArena}`. Extend `makeJitRuntime` for
  per-fixture `dispatch_override: ?[]const usize`. Relax
  `hasUnbindableImports` for registered aliases. Discharges
  D-138 partial.
- **(c)-2.3-γ LATER**: per-exporter backing buffers (memory +
  globals + tables). Required if `linking.wast` corpus uses
  any callee with state access; survey corpus first to confirm
  scope. Larger refactor; possibly Phase 9 close-plan step (e)
  or its own ADR.

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
