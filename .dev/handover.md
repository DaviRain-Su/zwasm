# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **Phase 9 extended; D-093 (d-1) landed 2026-05-12**

### One-line state

D-093 (d-1) landed (444d60e0): structural fix for dead-code
value propagation. lower.zig now tracks `unreachable_at_depth`
and strips post-br ZirInstrs; per-arch emit's `Label`
gains `entry_stack_depth`; emitEndIntra truncates
pushed_vregs at block/loop close. Mac + OrbStack
`test-spec-wasm-2.0-assert`: **11773 / 0 / 106
bit-identical** (no regression vs k-1-expand-2 baseline).
Verified sub-cluster progress on the deferred 8 names (kept
out of NAMES this chunk): pre-fix 30+ → post-fix 49 fails
(br: 4→1, labels: 5→3; br_if 29 and local_tee 9 unchanged
— need separate fixes).

### Standing reminder for the autonomous loop

**Project tone is `.claude/rules/no_workaround.md`: fix root
causes, never work around.** See
`.dev/lessons/2026-05-12-loop-defers-over-fixes-when-cost-high.md`.
On the next chunk's first obstacle, walk
`extended_challenge.md` Step 1 BEFORE reaching for a filter /
fallback / skip-ADR.

### Next task — D-093 (d-2): br/br_if/loop merge-MOV mechanism

(d-1) fixed the dead-code emission AND the block-end
truncation. Remaining 49 failures in the deferred 8 names
all reduce to a single missing mechanism: at br/br_if/return
to a block with `result_arity > 0`, the per-arch emit needs
to MOV the branch-value vreg into the target block's
canonical merge vreg, mirroring the if/else `merge_top_vregs`
mechanism. Without it, br's value is in whatever physical
register the regalloc happened to give the operand vreg, but
post-block code reads from the block's fall-through result
vreg — different registers.

Recipe (next chunk):
1. Extend `Label` to capture merge target vregs at FIRST br
   to the block (similar to emitElse's then-arm capture).
2. emitBr to block target with result_arity>0: if merge not
   captured, capture; else emit MOVs from current top to the
   captured merge target.
3. emitBrIf: same but conditional — emit the skip-CBZ around
   the marshal + B.
4. emitEndIntra (block kind): for fall-through, emit MOVs
   from current top to merge target. Existing truncation
   then collapses cleanly.

Sub-cluster failures still remaining post-(d-1):
- br_if: 29 (largest — same merge-MOV gap for br_if shape)
- local_tee: 9 (value flow through local.tee + outer op)
- labels: 3 (loop result via br-out)
- br: 1 (as-if-else complex shape)
- block: 2 (memory.grow + break-inner)
- nop: 3 (memory.grow)
- if: 1 (StackUnderflow validator/lower gap)
- loop: 1 (AllocationMissing JIT compile)

Other queued post-D-093 names: `address`, `align`, `br_table`,
`call`, `call_indirect`, `const`, `data`, `elem`, `f32_bitwise`,
`f64_bitwise`, `fac`, `func`, `func_ptrs`, `global`, `load`,
`memory`, `memory_grow`, `memory_size`, `select`, `start`,
`store`, `switch`, `table`, `traps`, `type`, `unwind`.

## Implementation queue (sequential)

Per-stage state of l-1 (all complete + D-092 close landed):

| Stage | Status | What |
|---|---|---|
| l-1a-1..6 | [x] | base extraction + runCorpus + arg-parser + makeJitRuntime hoists |
| l-1b-runner | [x] bff477f5 | new spec_assert_runner_non_simd.zig + test-spec-wasm-2.0-assert |
| l-1b-corpus | [x] 3b92bed6 | regen_spec_2_0_assert.sh + conversions starter |
| l-1b-widen  | [x] 774ae3c8 | 10 cross-type entry helpers + dispatch arms |
| l-1b-nan    | [x] 207330be | scalar NaN-pattern result matcher |
| l-1b-trap-widen | [x] a7bf59d8 | assert_trap f32/f64 arms + i32.wrap_i64 |
| k-1-expand-1 | [x] 894e0e00 | 6 binop helpers + 7 wasts |
| D-091-close | [x] f22acf6c | x86_64 i32.trunc_f64_s lower-bound `-(2^31+1)` + JBE |
| D-092-close | [x] 520246cd+111e232b | x86_64 emitFpMinMax dst==rhs swap; f32+f64 in NAMES |
| k-1-expand-2 | [x] a9b06a15 | 4 safe wasm-2.0 names (unreachable/local_get/local_set/return); D-093 filed for the other 8 |
| D-093 (d) root-cause | [x] 94b7840e | lower.zig + liveness gap analysis; impl recipe filed |
| D-093 (d-1) | [x] 444d60e0 | lower.zig unreachable tracking + emit block-end truncation; 30+ → 49 fails verified on deferred names |
| **D-093 (d-2)** | **NEXT** | br/br_if merge-MOV mechanism (mirror if/else's `merge_top_vregs` for block) |

Other queued chunks (post-l-1):
- k-1 — Wasm 2.0 non-SIMD wast vendor (~30 files).
- k-2 — SIMD wast vendor (33 files); standalone after l-1.
- m-4c (= D-090) — untyped `.select` non-i32 type inference.
- m-2d — table.grow JIT with allocator-helper infrastructure.
- n-1 — fib2 perf root cause.
- j-3b — SKIP gate real enforcement (last).

## Sandbox quirks + hook scope

- `~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- OrbStack daemon log-rotation panic — restart via
  `pkill -9 -f OrbStack && open -a OrbStack`.
- Per-chunk 2-host (Mac+OrbStack) per ADR-0049; windowsmini
  reconcile at §9.9 close.

## Open debt — see `.dev/debt.md`

- `now`: **D-093** (wasm-2.0 spec corpus failures cluster (a)/(b)/(c)/(d) — investigation).
- `blocked-by`: D-007/010/016/018/020/021/022/026/028/052(partial)/
  055/057/058/059/062(partial)/065/072/073/074/075/079(ii)/
  081/082/090.

## Reference chain

- `.dev/decisions/0057_spec_assert_runner_factoring.md` — Option B.
- `.dev/decisions/0058_table_ops_jit_design.md` — m-2 cluster.
- `private/notes/p9-99-l-1-spec-assert-survey.md` — factoring survey.
- `private/p9-close-next-session-pickup.md` — broader queue context.
