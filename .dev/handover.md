# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6 (revised 2026-05-18). ADR-0069 chunked plan + §9.13-0
   windowsmini relocation in §6 (d)/(f). D-135 closed; chain now
   leads with D-146.
2. **READ NEXT** ADR-0069 implementation chain + ADR-0049 /
   ADR-0056 / ADR-0065 2026-05-18 amends.
3. `git log --oneline -10`. Latest: D-135 invokeAndCheck refactor.
4. `bash scripts/p9_simd_status.sh` — live status.
5. `cat .dev/debt.md`. `now`: D-079, D-133. Blocked by D-146:
   D-094 / D-137 / D-140. Relocated to §9.13-0: D-084 / D-028 /
   D-136.

## Active state — §9.9-III [x]; §9.9-IV moved to §9.13-0; D-135 closed

D-126 + D-144 closed cycle 4; §9.9-III [x] cycle 5. D-145
closed cycle 10. Both hosts bit-identical **25316/0/697**.

2026-05-18 wiring: §9.9-IV → §9.13-0 (post-§9.12 audit) per
ADR-0049+0056+0065 amends. `skip-impl == 0 literally` preserved.
ADR-0066 §A2 (thunk 56→96 B), ADR-0069 chunked plan refined.

D-135 closed: `invokeAndCheck` / `invokeAndCheckVoid` generics
collapsed 97 of 99 helpers; Class B inline-asm thunks stay
hand-written. entry.zig 2445 → 2103 (~395 LOC headroom under
the 2500 exempt cap → fits D-146 x86_64 thunk).

### Next-session active task — D-146 (x86_64 inline-asm thunk for `(f64, f32)`)

Dependency chain to §9.9 [x]:

```
D-146 (cycle-11 (f64,f32) re-land + x86_64 inline-asm thunk)
  ↓
ADR-0017 + ADR-0026 amend (X8 / RDI hidden-result-ptr prologue)
  ↓
Class C (D-094 + D-140) — 5 chunks per arch
  ↓
§9.9 [x]  →  §9.12 substrate audit (USER GATE)  →
§9.13-0 windowsmini reconcile (LOOP)  →
§9.13 Phase 10 entry gate (USER GATE)
```

**Next concrete task**: D-146 — re-land `FuncRet_f64f32` +
`callF64f32NoArgs` with a parallel x86_64 SysV inline-asm thunk
(`call *fn; movq xmm0,r0; movq xmm1,r1` shape) alongside the
arm64 thunk. Both hosts must stay bit-identical post-land.
Side candidates if D-146 stuck: D-079 (latent), D-133 (latent).

### Discipline reminders

No `--no-verify`. 2-host per chunk (Mac + ubuntunote);
windowsmini at §9.13-0 (post-§9.12).

### Outstanding `now` debts

D-079; D-133.
Blocked by D-146 land: D-094 / D-137 / D-140.
Relocated to §9.13-0: D-084 / D-028 / D-136.

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
