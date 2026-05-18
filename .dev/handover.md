# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
   §6 (revised 2026-05-18). ADR-0069 chunked plan; Class C ABI
   end-to-end on both arches. Cat II residual = D-147 (1 shape)
   + D-140 (large-sig Phase 3 trivial extension).
2. **READ NEXT** D-147 debt entry — if-arm i64 truncation
   blocking the last `(i32) → (i32, i32, i64)` shape.
3. `git log --oneline -10`. Latest: Class C 3-int-result
   helpers + runner dispatch (b)-e-4/5 partial.
4. `bash scripts/p9_simd_status.sh` — live status.
5. `cat .dev/debt.md`. `now`: D-079, D-133, **D-147** (new).

## Active state — Cat II nearly closed; D-147 + D-140 residual

D-126 + D-144 closed cycle 4; §9.9-III [x] cycle 5. D-145
closed cycle 10. D-135 + D-146 + D-137 closed. Class C ABI
complete on both arches (arm64 X8 + x86_64 R11 internal).

5-shape entry-helper + runner dispatch landed (b)-e-4/5
partial: `value-i32-i32-i32` / `return-i32-i32-i32` /
`break-i32-i32-i32` (func.wast) + `break-multi-value`
(block.wast + loop.wast). Mac + ubuntunote bit-identical
**25322/0/691** (= 196 skip-impl + 495 skip-adr).

Remaining Cat II skip-impl multi-result:
  - 2× `break-multi-value` in if.wast (`(i32) → (i32,i32,i64)`)
    blocked by **D-147**: i64.const-with-high-bits truncates
    to W-form somewhere in the if-arm merge path. Pre-existing
    latent surfaced by chunk (b)-e-4's dispatch wiring.
  - 1× `large-sig` 16-result (D-140 Phase 3 trivial).

### Next-session active task — D-147 close

Dependency chain to §9.9 [x]:

```
D-147 (if-arm i64 truncation) — investigate via byte-dump of
        `if.wast::break-multi-value` JIT body; suspect vreg
        class mis-tag in lower → merge → MEMORY-class path.
  ↓
D-140 (large-sig 16-result) — ADR-0069 §Phase 3 trivial
        extension: bump per-class result cap or use indirect-
        result-ptr for >8 same-class results.
  ↓
§9.9 [x]  →  §9.12 substrate audit (USER GATE)  →
§9.13-0 windowsmini reconcile (LOOP)  →
§9.13 Phase 10 entry gate (USER GATE)
```

**Next concrete task**: D-147 fix — implement parallel-move
algorithm in `op_control.zig::captureOrEmitBlockMergeMov`
(arm64) + x86_64 mirror. Root cause confirmed via byte-dump
at `33a3eee3`: 3-cycle (X9←X10, X10←X11, X11←X9) destroys
the i64 source on step 1. Discharge plan (per lesson
`2026-05-18-parallel-move-cycle-in-if-merge.md` + D-147
row): pre-spill all sources to a `merge_scratch` region in
the frame (N×8 B; reuse outgoing-args slot when free, else
grow `frame_bytes` like `indirect_result_slot_bytes`); load
+ store from there to dest's home. Doubles MOV count for
affected multi-value merges; cold path. Symmetric fix
needed on x86_64 (LIFO slot reuse + sequential merge MOVs
same shape). Re-enable `(('i32',), ('i32', 'i32', 'i64'))`
in supported_multi → +2 PASS.

### Discipline reminders

No `--no-verify`. 2-host per chunk (Mac + ubuntunote);
windowsmini at §9.13-0 (post-§9.12). D-147 investigation per
`.claude/rules/extended_challenge.md` Step 5 — every cycle
should land permanent diagnostic infra (lesson if observational,
ADR if load-bearing).

### Outstanding `now` debts

D-079; D-133; **D-147** (new). Blocked: D-140 (Phase 3 trivial).
Relocated to §9.13-0: D-084 / D-028 / D-136.

## Sandbox + References

`~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
Per-chunk 2-host; windowsmini Phase-boundary batch.

PRIMARY: [`phase9_close_plan.md`](phase9_close_plan.md).
ADRs: [`0017`](decisions/0017_jit_runtime_abi.md) (2026-05-18
amend) / [`0026`](decisions/0026_x86_64_runtime_invariant_strategy.md)
(2026-05-18 amend) / [`0069`](decisions/0069_multi_result_return_abi.md)
§Phase 2.
Lessons: [`2026-05-18-class-c-callee-without-caller-segvs-fac.md`](lessons/2026-05-18-class-c-callee-without-caller-segvs-fac.md)
(bundling rule).
