# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — (c)-1/(c)-2.0/(c)-2.1/(c)-2.2 landed;
   **next = (c)-2.3 resolver wire-up**.
2. `git log --oneline -15`. 2026-05-17 batch:
   `58e69207` Ubuntu pivot + D-134 closure (ADR-0067) →
   `bdb47eb9` review fix-ups → `ab973f56` (c)-2.2 thunk arena.
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

### Next-session active task — (c)-2.3 Resolver wire-up

Per ADR-0066 §Implementation: in `setupRuntime`
(`src/engine/runner.zig`) walk `compiled.module.imports`; for
each func import, `store.lookup(import.module)` → registered
`*Instance` (cast from `*anyopaque`); resolve named export to
exporter's JIT entry via `JitModule.entry` + capture
`*JitRuntime`; allocate arena once
(`shared.thunk.allocArena`, empty-arena sentinel for zero
cross-module imports); emit per slot
(`shared.thunk.emitThunk(thunkSlot(...), callee_rt,
callee_entry)`); plant `host_dispatch_base[idx] =
@intFromPtr(slot.ptr)`; `finalizeArena` after all slots.
Extend `JitModule` with `thunk_block: jit_mem.JitBlock` +
`freeArena` in `deinit`. Unresolved imports keep existing
`hostImportTrapStub` / `hostDispatchTrap`.

Test fixture (this or (c)-2.4): smallest `(register "M" $inst)`
+ cross-module call mutating exporter state with non-zero
return → discharges D-138; v128 result fixture covers D-079
sub-gap ii.

Open Qs: `Store.instances` is `*anyopaque`-keyed (D-139
spec-runner-bypass) — confirm cast shape early;
`Instance.exports` findExport API vs runner walk.

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
