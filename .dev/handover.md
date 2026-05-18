# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6. Cat III dispatch — D-126 + D-144 CLOSED 2026-05-18. γ-4
   permanent relax landed.
2. **READ NEXT** ADR-0066 §A2 amendment (bridge thunk 56 → 96 B
   for full pinned cohort);
   [`.dev/lessons/2026-05-18-thunk-pinned-cohort-not-just-x19.md`](lessons/2026-05-18-thunk-pinned-cohort-not-just-x19.md).
3. `git log --oneline -10`. Latest: γ.4 cycle 4 close.
4. `bash scripts/p9_simd_status.sh` — live SIMD status.
5. `cat .dev/debt.md | head -90`. Next candidates: D-079, D-133.

## Active state — §9.9-III [x] (Cat III CLOSED)

D-126 (dual-view table) + D-144 (print64 cross-module trap)
both closed 2026-05-18 cycle 4. §9.9-III row flipped [x]
cycle 5 (144-directive drain target satisfied).

D-144 root cause: arm64 bridge thunk's ADR-0066 §A1 saved
only X19, missing X24-X28 (the full reserved-invariant
cohort per `abi.zig::reserved_invariant_gprs`). Cross-module
BLR return left caller's X24 holding callee's typeidx_base
→ `call_indirect sig` mismatch (`kind=3`).

Fix: ADR-0066 §A2 grows arm64 thunk 56 → 96 B for full
cohort save/restore. x86_64 unchanged (R15 only pin per
ADR-0026; other invariants reload from `[R15+off]`).

2-host gate after fix: Mac 25308/0, ubuntunote 24034/0
with γ-4 relax PERMANENT.

### Permanent diagnostic infra landed in γ.4

- Cycle 2/3: `host_import_stub_call_count` / `_last_trap_flag`
  globals + `tf=` (rt.trap_flag) — `[stubs=N last_tf=M tf=K]`.
- Cycle 4: `JitRuntime.trap_kind` (replaces `_pad1`) +
  per-fixup-class arm64 trap stubs (1=generic, 2=cind
  bounds, 3=cind sig). `printCallTrap` emits `kind=N`.

### Next-session active task — D-145 x86_64 D-126 mirror gap

Cycle 9 landed Class B (i32,f64)/(f64,i32) helpers (Mac
25316/0; ubuntu re-baseline surfaced 24 pre-existing
table_init/copy fails — D-145). Highest priority: discharge
D-145 (audit x86_64/op_table.zig mirror code, extend
trap_kind to x86_64 trap stubs). After D-145: §9.9-II Class C
or §9.9-IV per ADR-0069 chunked plan.

### Discipline reminders

Pre-commit hook active; no `--no-verify`. 2-host per chunk;
windowsmini batch at Phase 9 close.

### Outstanding `now` debts

D-079; D-133; **D-145** (x86_64 D-126 mirror gap surfaced
cycle 9 — 24 ubuntu table_init/table_copy fails; cycle-4
closure claim of ubuntu 24034/0 was mis-measured).

## Sandbox + References

`~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
Per-chunk 2-host; windowsmini Phase-boundary batch.

PRIMARY: [`phase9_close_plan.md`](phase9_close_plan.md).
ADRs: [`0065`](decisions/0065_wasm_1_0_instance_work_phase9_rescope.md)
/ **[`0066`](decisions/0066_cross_module_import_bridge_thunks.md)** §A2
/ [`0067`](decisions/0067_ubuntunote_native_x86_64_gate_host.md)
/ [`0068`](decisions/0068_dual_view_table_storage_fix.md).
Auto-loaded rules: [`abi_callee_saved_pinning.md`](../.claude/rules/abi_callee_saved_pinning.md)
(full cohort discipline); [`dual_view_table_sync.md`](../.claude/rules/dual_view_table_sync.md);
[`hypothesis_enumeration.md`](../.claude/rules/hypothesis_enumeration.md).
