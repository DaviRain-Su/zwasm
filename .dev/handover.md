# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **Phase 9 extended; D-093 (d-5) landed 2026-05-13**

### One-line state

D-093 (d-5) landed: per-arch `emitEndIntra` final-truncate
pads pushed_vregs with a placeholder vreg when `.loop`
fall-through is dead (= loop body ends with backward `br`,
no producer reached the loop result). Per-arch function-end
marshal guards on `top_vreg < alloc.slots.len` so the
placeholder doesn't crash the slot lookup (the marshal is
unreachable at runtime; the function never returns when its
result depends on a dead-fall-through loop). Mac + OrbStack
`test-spec-wasm-2.0-assert` unchanged at **11773 / 0 / 106
bit-identical** baseline. Out-of-band: 10 → **17 FAIL** but
+69 PASS (net +62) — `loop/loop.0.wasm` compile gate cleared
unmasked 76 previously-hidden fixtures; 7 of them are
multi-value block-param shapes (new sub-cluster).

### Standing reminder for the autonomous loop

**Project tone is `.claude/rules/no_workaround.md`: fix root
causes, never work around.**

### Next task — D-093 residual sub-clusters

Residual 17 fails on deferred-name out-of-band run:

- **memory.grow JIT skeleton (cluster (a))** — 6 fails:
  nop:as-memory.grow-{first,last,everywhere},
  block:as-memory.grow-value, loop:as-memory.grow-value,
  local_tee:as-memory.grow-size. Needs runtime callout.
- **wasm-2.0 block-param multi-value (new)** — 7 fails:
  block:{param,params,params-id}, loop:{param,params,
  params-id,params-id-break}. Block opens with `(param T..)`
  popping arity values from the operand stack; emit's
  emitBlock currently doesn't handle param consumption.
- **br_table forward merge** — 2 fails:
  br_if:nested-br_table-value{,-index}. emitBrTable per-case
  capture-or-MOV + variable-disp JNE-skip. Separate chunk.
- **validator gap** — 1 fail: if/if.0.wasm StackUnderflow.
- **block:break-inner off-by-one** — 1 fail. Mystery; the
  d-3-style lower fix regresses realworld.

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
| D-093 (d-5) | [x] (this commit) | loop dead-fall-through placeholder + marshal guard |
| **D-093 residual** | **NEXT** | wasm-2.0 block-param multi-value OR memory.grow OR br_table |

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
- `private/notes/p9-99-l-1-spec-assert-survey.md`.
