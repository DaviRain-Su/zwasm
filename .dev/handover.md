# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **Phase 9 extended; D-093 (d-11) landed 2026-05-14**

### One-line state

D-093 (d-11) landed: multi-result function call support across
arm64 + x86_64 (captureCallResult + function-end marshal).
arm64: results map to X0..X7 (GPR class) and V0..V7 (FP / SIMD
class) per AAPCS64 §6.5; independent class counters; cap 8
per class. x86_64 SysV: RAX/RDX + XMM0/XMM1 (cap 2 per class
per §3.2.3); Win64: cap 1 per class (§3.2.4). Shared
`marshalFunctionReturn` (arm64) and `marshalReturnRegs`
(x86_64) helpers replace the previous single-result inline
marshal blocks at `.return` op + function-level `.end` op +
`emitBr`/`emitBrIf` fn-depth paths. **No parallel-move
hazard**: allocatable pools exclude the result regs by design.
Edge-case fixture `test/edge_cases/p9/call/multi_result_
i64_i32.wasm = 1253` verifies the multi-result path on both
arches. Mac + OrbStack `test-spec-wasm-2.0-assert` 12262 / 0 /
143 unchanged (`if` deferred — adding it surfaces a separate
if-merge slot-share invariant gap; see d-12 in queue). simd
unchanged 13301/0/440.

### Standing reminder for the autonomous loop

**Project tone is `.claude/rules/no_workaround.md`: fix root
causes, never work around.**

### Next task — D-093 if-merge canonical-slot + runner-skip-impl

Clusters (a) + (b) + (c) of D-093 ALL DISCHARGED. Multi-result
func calls (d-11) DISCHARGED. Remaining gating §9.9 close:

- **if-merge canonical-slot (d-12)** — Adding `if` to NAMES
  surfaces 9 failures on `if.wast` exposing a design gap:
  emit's if-result merge mechanism relies on regalloc luck for
  V_then_i and V_else_i to share a slot (so the .end merge
  MOV is a no-op). Single-result single-if works by accident
  (free-list first-fit picks the freed V_then slot for V_else);
  multi-result OR compose-of-2-ifs breaks the assumption.
  Proper fix: emit pre-allocates canonical merge slots at
  `.if`; both arms MOV their results into the canonical slots
  before transferring control to .end; .end is a no-op.
  Failures observed: `as-binary-operands`,
  `as-compare-operand[s]`, `as-mixed-operands`, `param-break`,
  `params-break`, `add64_u_saturated`. ~9 fails clears.

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
| D-093 (d-11) | [x] (this commit) | multi-result function calls (arm64 + x86_64 captureCallResult + marshalReturn shared helpers) + edge-case fixture |
| **D-093 (d-12)** | **NEXT** | if-merge canonical-slot (emit pre-allocates merge slots; both arms MOV into them; .end no-op) + add `if` to NAMES |

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
- `private/notes/p9-99-l-1-spec-assert-survey.md`.
