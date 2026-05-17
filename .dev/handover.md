# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — γ-5 landed (`552a2b6d` /
   `e902e531`). D-142 fix (B) landed (`d543c646`); (A) is
   next.
2. `git log --oneline -10`. Latest: D-142 fix (B). Prior β/γ
   chain via `git log --grep="9.9-III"`.
3. `bash scripts/p9_simd_status.sh` — live SIMD via ubuntunote
   native x86_64 (ADR-0067).
4. `cat .dev/debt.md | head -90`. Cat III sub-chunks tracked
   in close-plan §6 step (c), not granular ROADMAP rows.

## Active state — Phase 9 close-plan Step (c)-2.3

D-134 closed structurally. Cat III JIT dispatch infra:
registry (c)-1a/b/c; ADR-0066 design (c)-2.0; arm64 32-byte
/ x86_64 22-byte opcode-pinned thunk encoders (c)-2.1;
`shared/thunk.zig` arena lifecycle (c)-2.2; resolver
substrate + wire-up (c)-2.3-α/β-1/β-2a/β-2b. γ-1/γ-2/γ-3/
γ-3.b-i/γ-3.b-ii/γ-5 all landed
(`9518eb4d`/`413d9b57`/`33d1da17`/`3b003b9e`/`84f62398`/
`e902e531`). Counts unchanged with γ-relaxation deferred:
24034/0/2015 + 13301/0/440 + 212/0/20.

### Next-session active task — D-142 fix (A)

D-142 root cause is two interacting bugs (cycle 6, see
lesson `2026-05-17-gamma3d-dispatch-write-segv-bisect.md`):

- **(A) bridge thunk corrupts X19** across cross-module call
  (AAPCS64 §6.4.1 violation: v2 arm64 prologue overwrites
  `runtime_ptr_save_gpr` without saving caller's value).
- **(B) `ensureCompiledAndRt` leaves `host_dispatch_base`
  poison-initialised** — once (A) corrupted X19 to point at
  the wrong rt, the next host-import call dereferenced 0xAA
  poison at offset +8 → fault at `0xAA + 8 = 0xB2`.

(B) **landed** (`d543c646`): `SAFE_STUB_PTR_ADDR = 0x1000`
constant + all 8 absent-backing `[*]const T` fields recast
to `@ptrFromInt(stub_ptr)`. Attendant test-wiring discharged
orphan γ-1/γ-2/γ-3/γ-3.b-i tests (now `zig build test` runs
them); γ-1 wasm + deinit alignment fixes paid down
pre-existing rot the wiring exposed.

**NEXT — D-142 fix (A)**: bridge thunk redesign so X19 is
preserved across cross-module BLR. Requires ADR-0066
amendment (load-bearing ABI change → file
`.dev/decisions/NNNN_bridge_thunk_x19_save.md` per §18
FIRST, then implementation). Both arm64 + x86_64 thunk
encoders need updates; `thunk_bytes` constant grows from 32
(arm64) / 22 (x86_64). Estimated shape: BL/RET pattern
saving caller's X19 (arm64) / RBX (x86_64) on the thunk's
own stack frame. After (A) lands, γ-4 (relax
`hasUnbindableImports`) can finally land, unblocking
(c)-2.4 distiller + D-079 (ii) + D-105 + D-126
Cat-III-dependent pieces.

(c)-2.4 = corpus distiller's `supported` set extension +
new fixture rebuild; discharges D-138 fully + D-079 sub-gap
ii.

### Discipline reminders

Pre-commit hook active (`gate_commit.sh`); no `--no-verify`
per §14. 2-host gate per chunk: Mac foreground +
`bash scripts/run_remote_ubuntu.sh test-all > /tmp/ubuntu.log 2>&1`
background. D-134 closed; future heisenbugs use 5-streak +
3-SHA rule.

### Outstanding `now` debts (6)

D-016(applySanitize wrapper); D-052(x86_64 prologue extract);
D-079(v128 cross-module → (c)-2.4); D-126(bulk.wast post-
mutation per ADR-0065); D-133(arm64 op_table scratch sweep);
D-142(Mac aarch64 SEGV — (B) closed, (A) remaining).

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
[`lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md`](lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md)
· [`lessons/2026-05-17-gamma3d-dispatch-write-segv-bisect.md`](lessons/2026-05-17-gamma3d-dispatch-write-segv-bisect.md).
