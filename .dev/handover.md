# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — D-142 fix (B) `d543c646` + (A.1)
   ADR-0066 amendment `4e7a4646` + (A.2) arm64 thunk
   redesign `6044e8f4` all landed. (A.3) x86_64 mirror is
   next.
2. `git log --oneline -10`. Latest: D-142 (A.2) arm64 thunk
   redesign. Prior β/γ chain via `git log --grep="9.9-III"`.
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

### Next-session active task — D-142 fix (A.3) x86_64 mirror

D-142 progress (cycle 6 root-cause + 3 fix sub-chunks):

- **(B) `d543c646`** — `ensureCompiledAndRt`
  `SAFE_STUB_PTR_ADDR = 0x1000` for all 8 absent-backing
  `[*]const T` fields (closed the poison-init half).
- **(A.1) `4e7a4646`** — ADR-0066 Amendment §A1 landing the
  bridge-thunk-saves-caller-X19 design contract (docs-only).
- **(A.2) `6044e8f4`** — arm64 thunk redesign per §A1:
  56-byte STP/STR/BLR/LDR/LDP/RET shape + 3 new encoders
  (`encBlr`, `encStpPreIdx`, `encLdpPostIdx`). Closes the
  X19-corruption half of D-142 on Mac aarch64.

**NEXT — D-142 fix (A.3)**: x86_64 mirror of A.2. Replace
`src/engine/codegen/x86_64/thunk.zig`'s tail-call shape
(MOV imm64 + JMP RAX, 22 bytes) with a call-and-return
shape that PUSHes R15 (= x86_64 `runtime_ptr_save_gpr` per
ADR-0026 Cc-pivot) before the CALL and POPs after. Target
shape per ADR-0066 §A1:

  PUSH R15                       ; save caller's R15 = caller_rt
  MOV  RDI, <callee_rt imm64>    ; SysV arg0
  MOV  RAX, <callee_entry imm64>
  CALL RAX                       ; SysV CALL (not JMP)
  POP  R15                       ; RESTORE caller's R15
  RET

`thunk_bytes` grows from 22 to 27. Likely new encoders:
`encPushReg64`, `encPopReg64`, `encCallReg64` (SysV `0x41 0x57`
/ `0x41 0x5F` / `0xFF 0xD0` family). Mirror the test shape
A.2 used (byte-exact + structural PUSH/POP-bracket-CALL
assertion).

After A.3 lands, γ-4 (relax `hasUnbindableImports` in
`spec_assert_runner_base.zig`) can finally land, unblocking
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
D-142(Mac aarch64 SEGV — (B) + (A.1) + (A.2) landed, (A.3) x86_64 remaining).

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
