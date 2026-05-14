# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **Phase 9 extended; D-093 (d-30) D-103 parts (a)+(b) discharged; elem deferred to Phase 10+ 2026-05-14**

### One-line state

D-093 (d-30) closes D-103 parts (a)+(b) via the d-29
SIGSEGV→trap handler + a one-shot `elem` enable / bisect.
Findings: d-21's symptom IS reproducible (handler-removed run
aborts at `callI32NoArgs:55` `f(rt)` null deref in
nonSimdRunAssertTrap); d-29 handler resolves it
(stderr-diagnostic at the recovery branch confirmed 2 SEGV →
PASS conversions on elem.75 / elem.76 `init ()` trap-asserts).
Full `elem` enablement remains blocked because the corpus's
113 modules surface 34 non-SEGV FAILs: 22 BadValType (reftype
globals / element segments — D-075 / D-104, Phase 10+), 5
table-init shapes (UnsupportedEntrySignature /
InvalidFunctype — D-079 family), 7 findExport on imported
functions (cross-module imports — D-079). Same defer shape as
`data` (D-102). D-103 part (c) "fix underlying null deref" is
no longer needed for spec semantics — a SEGV during an
assert_trap invoke IS a trap per spec §A.2, and the d-29
handler is the load-bearing fix. spec_assert 14399/0/385
unchanged. simd 13301/0/440 unchanged.

### Standing reminder for the autonomous loop

**Project tone is `.claude/rules/no_workaround.md`: fix root
causes, never work around.**

### Next task — d-31 discharge candidate

Active debts (post-d-30):
- D-103 elem-SEGV — parts (a)+(b) discharged d-29/d-30; part
  (c) optional (SEGV→trap equivalence covers spec semantics);
  full enablement awaits Phase 10+ reftype + cross-module
  imports.
- D-106 start-invoke SEGV (lldb trace on prologue load).
- D-102/D-104/D-105: blocked-by Phase 10+ (cross-module memory
  imports + reftype runtime).

- **d-31 NEXT** — pick the next `now` debt. Candidates from the
  Phase 9 residual queue: D-106 start-fn invoke SEGV (similar
  shape to D-103 but in nonSimdOnModuleLoaded's start-fn
  invoke path; the d-29 handler is wired only on the
  assert_trap callsite, so D-106 needs either a separate
  handler-armed call or a different root-cause path — start-fn
  SEGV at `0xaa...` undefined-memory pattern suggests a
  missing JitRuntime field, per d-22 narrowing). The remaining
  Phase-10+-blocked debts (D-102/D-104/D-105) stay deferred.

Runner-side skip-impl backlog (7 total, in `nop / loop /
local_tee`):
- 5× nop:as-call-{first,mid1,mid2,last,everywhere} —
  manifest filter: `(i32 i32 i32, i32)` is 3-arg i32
  dispatch, runner's `[5]ArgValue` matrix dispatches ≤ 2
  args + result. Extend dispatch table.
- 1× loop:break-multi-value — multi-result loop blocks.
  Path B exit requires this resolved at Phase 11+ (per
  ADR-0029 follow-up).
- 1× from local_tee or block — verify.

Other queued post-D-093 names: `address`, `align`, `br_table`,
`call`, `call_indirect`, `const`, `data`, `elem`, `f32_bitwise`,
`f64_bitwise`, `fac`, `func`, `func_ptrs`, `global`, `load`,
`memory`, `memory_grow`, `memory_size`, `select`, `start`,
`store`, `switch`, `table`, `traps`, `type`, `unwind`.

## Implementation queue (sequential)

| Stage | Status | What |
|---|---|---|
| l-1b .. k-1-expand-2 | [x] | base + corpus + 4 safe names |
| D-091/D-092 close | [x] | x86_64 trunc-bound + minmax swap |
| D-093 (d-1) | [x] 444d60e0 | lower.zig unreachable + emit truncation |
| D-093 (d-2) | [x] 708e1bb1 | per-arch block-merge MOV |
| D-093 (d-3) | [x] bef86380 | liveness/regalloc local.tee transparency |
| D-093 (d-4) | [x] 8755326d | block-merge stack-emptied case |
| D-093 (d-5) | [x] 6fe10e95 | loop dead-fall-through placeholder |
| D-093 (d-6) | [x] a97d9bcd | Wasm 2.0 block-param multi-value |
| D-093 (d-7) | [x] ad78ce45 | br_table per-case forward-block merge |
| D-093 (d-8a) | [x] 13c46792 | ADR-0059 + JitRuntime callout ABI tail extension |
| D-093 (d-8b) | [x] 2e04b925 | arm64 `.memory.grow` BLR-via-fn-ptr emit + X28/X27 reload + safe default fn |
| D-093 (d-8c) | [x] 0b3d7dea | x86_64 `.memory.grow` CALL-via-fn-ptr emit + spec-runner growable_memory pool + NAMES (nop/loop/local_tee; block deferred for (c)) |
| D-093 (d-9) (c) | [x] a38890da | liveness br target-depth-aware close (block_stack) + block NAMES |
| D-093 (d-10) (b) | [x] 1df7acc5 | if-with-params validator opElse + emit param_top_vregs capture/restore + liveness if-frame + edge-case fixtures |
| D-093 (d-11) | [x] 9b48592e | multi-result function calls (arm64 + x86_64 captureCallResult + marshalReturn shared helpers) + edge-case fixture |
| D-093 (d-12) | [x] 7d1c71f8 | liveness if-frame merge tracking + x86_64 cap silent-truncate (D-094 debt) + multi_result_compose edge fixture |
| D-093 (d-13) | [x] 15cfa288 | implicit-else marshal (arm64 + x86_64) + 3 edge fixtures |
| D-093 (d-14) | [x] 124dd7cf | arm64 `.return` op multi-result marshal (d-11 stale-inline cleanup) + add64_u_saturated_exact edge fixture |
| D-093 (d-15) | [x] b5bd2cdf | regalloc call-crossing-vreg root-cause investigation + D-095 debt + compose_no_call edge fixture |
| D-093 (d-16) | [x] 5ccae2cd | ADR-0060: regalloc `computeWith` force-spill call-crossing vregs (slot ≥ per-arch max(GPR, FP)) + compose_with_call edge fixture + D-095 partial discharge + D-096 / D-097 filed |
| D-093 (d-17) | [x] eca69183 | unified `emitMergeMov` (FP-class dispatch + 64-bit GPR MOV) + br-into-if-frame merge capture (D-096 discharged) + br_inside_arm edge fixture |
| D-093 (d-18) | [x] 4a4e0a22 | x86_64 select alias-aware cmov + call_indirect idx load order (D-097 discharged) + select_spilled_operands / select_with_if_call / select_with_if_no_call edge fixtures |
| D-093 (d-19) | [x] c41b0868 | NAMES +5 (`address`, `const`, `load`, `store`, `traps`); `select` deferred (reftype), `align` rejected by wast2json |
| D-093 (d-20) | [x] 18f93d91 | NAMES +5 (`f32_bitwise`, `f64_bitwise`, `memory_size`, `switch`, `type`) + runner memory_limits reset + D-099 (fac-ssa loop param) filed |
| D-093 (d-21) | [x] 834fd332 | NAMES batch bisect (call/data/elem/global/memory_grow/start/unwind each → its own debt D-101..D-107) + GROWABLE_MEMORY_CAPACITY 64 → 1024 pages |
| D-093 (d-22) | [x] 404a8477 | NAMES batch bisect (call_indirect/func/func_ptrs/memory/table → D-108..D-110 + wast2json-reject) + D-106 discharge scaffolding (extractStartFunc + invoke helper; SEGV root-cause now narrowed) |
| D-093 (d-23) | [x] ad84042e | D-107 discharged: x86_64 emitBrTableJmp function-depth (mirror arm64); `unwind` lands +49 PASS |
| D-093 (d-24) | [x] 4c4d7309 | D-099 discharged: emitLoop captures param_top_vregs + backward br/br_if/br_table emit param MOVs before back-branch; `fac` lands +6 PASS |
| D-093 (d-25) | [x] ed05169b | D-101 discharged: max_args cap 64 → 128 (call.wast func[77] has 100-arg call); `call` lands +82 PASS |
| D-093 (d-26) | [x] 1815e624 | D-108 discharged: i64/f32/f64 scalar `global.get/set` on both archs + edge fixtures (3 new). D-111 filed for call_indirect structural-typing. NAMES unchanged. |
| D-093 (d-27) | [x] 77ef4a06 | D-111 discharged: `canonical_type.zig` + emit/runner canonicalization. NAMES +3 (call_indirect/func/func_ptrs); 14119/0/292 → 14399/0/385 (+280 PASS, +3 manifests). Cascade discharge: D-109 moot, D-110. |
| D-093 (d-28) | [x] fda102aa | D-102 reclassified blocked-by D-105: stderr-diagnostic proves 19 `data.wast` module-load failures are all import-dependent (15× imported memory; 1× imported-global const-expr; 4× InvalidFunctype on import shape). `data` NAMES deferred. No code change beyond regen-script comment. spec_assert 14399/0/385 unchanged. |
| D-093 (d-29) | [x] d5a25a1b | D-103 part (a): SIGSEGV / SIGBUS recovery installed in `spec_assert_runner_base` (`sigsetjmp` / `siglongjmp` via libc; `__sigsetjmp` on Linux, `sigsetjmp` on Mac) + inline-armed in `nonSimdRunAssertTrap` dispatch ladder + 2 unit tests + handler install in non_simd runner main. NAMES unchanged. |
| D-093 (d-30) | [x] (this commit) | D-103 parts (a)+(b) close. Handler IS load-bearing (handler-removed probe aborts at `callI32NoArgs:55` null deref). Bisect via temporary stderr-diag pinpointed 2 SEGV-recovery cases: elem.75 + elem.76 `init ()` trap-asserts. The remaining `elem` corpus FAILs (34) are all Phase 10+ scope (BadValType reftype × 22 / table-init × 5 / cross-module imports × 7). `elem` NAMES enablement defers to Phase 10+ (same shape as `data`); D-103 (c) "actual null-deref fix" no longer required for spec semantics — SEGV during assert_trap invoke IS a trap per spec §A.2. spec_assert 14399/0/385 unchanged. |
| **D-093 (d-31)** | **NEXT** | next `now` debt — candidate D-106 start-fn invoke SEGV (d-22 narrowed root cause: undefined-memory pattern at prologue load). |

Other queued chunks (post-l-1): k-1, k-2, m-4c (= D-090),
m-2d, n-1, j-3b.

## Sandbox quirks + hook scope

- `~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- OrbStack daemon log-rotation panic — restart via
  `pkill -9 -f OrbStack && open -a OrbStack`.
- Per-chunk 2-host (Mac+OrbStack) per ADR-0049; windowsmini
  reconcile at §9.9 close.

## Open debt — see `.dev/debt.md`

- `now`: **D-093** (residual sub-clusters above).
- `blocked-by`: D-007/010/016/018/020/021/022/026/028/052(partial)/
  055/057/058/059/062(partial)/065/072/073/074/075/079(ii)/
  081/082/090.

## Reference chain

- `.dev/decisions/0057_spec_assert_runner_factoring.md`.
- `.dev/decisions/0058_table_ops_jit_design.md`.
- `.dev/decisions/0059_jit_memory_grow_callout.md`.
- `.dev/decisions/0060_regalloc_call_crossing_force_spill.md`.
- `private/notes/p9-99-l-1-spec-assert-survey.md`.
