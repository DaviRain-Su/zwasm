# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **Phase 9 extended; D-093 (d-8c) landed 2026-05-13**

### One-line state

D-093 (d-8c) landed: x86_64 `.memory.grow` CALL-via-fn-ptr emit
(SysV: RDI=rt, ESI=delta; Win64 via `entry_arg0_gpr` + shadow
alloc) + spec-runner restructure (`base.growable_memory: [64 ×
65536]u8` pool replaces per-runner `scratch_memory[65536]`;
`base.current_mem_bytes` tracks module-scoped persistent size;
`base.growableMemoryGrowFn` is the callout that updates both
`current_mem_bytes` + `rt.mem_limit` in place) + NAMES expansion
to `nop / loop / local_tee` (block deferred — see Next). All 5
memory.grow cluster (a) fixtures clear: Mac + OrbStack
`test-spec-wasm-2.0-assert` 11773/0/106 → **12056 / 0 / 127**
bit-identical (+283 PASS, 0 FAIL, +21 skip = 6 runner-shape-gap
skip-impls (3-arg + multi-value-break) + 15 skip-adr). cluster
(a) DISCHARGED.

### Standing reminder for the autonomous loop

**Project tone is `.claude/rules/no_workaround.md`: fix root
causes, never work around.**

### Next task — D-093 residual sub-clusters

Cluster (a) memory.grow DISCHARGED at d-8c. Remaining:

- **block:break-inner off-by-one (cluster (c))** — adding
  `block` to NAMES surfaces `break-inner → got 16,
  expected 15`. The fixture chains 4 `(block (result i32)
  ... (br N (i32.const X)))` patterns + an inner-vs-outer
  br depth alternation; one block's contribution is +1
  too high. Likely a residual case of multi-nested
  br-value propagation (D-093 d-2 / d-4 / d-7 family).
  Investigation: write minimal repro (one of the 4 chunks
  in isolation), disassemble Mac arm64 output, trace
  the +1 source. Localise + fix + add `block` to NAMES.
- **if-with-params validator + emit gap (cluster (b))** —
  `if.wast:param` (func[42]) is `(if (param i32) (result
  i32) ...)`. Validator's `opElse` doesn't re-push params
  for else-arm (Wasm spec §3.4.4); fixing validator alone
  surfaces an emit-side gap (liveness treats `.else` as
  transparent so param vreg's range ends in then-arm; else
  re-read clobbers via regalloc slot reuse). Multi-file
  chunk: (a) validator opElse re-push, (b) emit Label
  param_top_vregs capture at emitIf + restore at emitElse,
  (c) liveness if-frame stack to extend param vreg ranges
  across both arms.

Runner-side skip-impl backlog (6, all in `nop / loop`):
- 5× nop:as-call-{first,mid1,mid2,last,everywhere} —
  manifest-side rejection: `(i32 i32 i32, i32)` is 3-arg
  i32 dispatch, runner's `[5]ArgValue` matrix dispatches
  ≤ 2 args + result. Extend dispatch table.
- 1× loop:break-multi-value — multi-result loop blocks.
  Path B exit requires this resolved at Phase 11+
  (per ADR-0029 follow-up).

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
| D-093 (d-8c) | [x] (this commit) | x86_64 `.memory.grow` CALL-via-fn-ptr emit + spec-runner growable_memory pool + NAMES (nop/loop/local_tee; block deferred for (c)) |
| **D-093 (d-9) (c)** | **NEXT** | block:break-inner off-by-one localisation + fix + add `block` to NAMES |
| D-093 (d-10) (b) | queued | if-with-params validator opElse re-push + emit Label param_top_vregs + liveness if-frame stack |

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
