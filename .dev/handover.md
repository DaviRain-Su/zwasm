# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **Phase 9 extended; D-093 (d-6) landed 2026-05-13**

### One-line state

D-093 (d-6) landed: Wasm 2.0 multi-value block-param
support. `lower.zig:readBlockArity` packs both `param_arity`
and `result_arity` into `ZirInstr.extra` (`(params << 8) |
results`); per-arch `Label.param_arity` field; emitEndIntra
truncate uses `new_len = entry - param_arity + result_arity`
so the post-block height is correct when the body consumed
the params. Also tightens d-5 placeholder pad to
`lbl.kind == .loop` only — block-merge handles its own
shape (d-2/d-4 case (c)). Mac + OrbStack
`test-spec-wasm-2.0-assert` unchanged at **11773 / 0 / 106
bit-identical** baseline. Out-of-band: 17 → **10 FAIL** (+7
PASS, all 7 block/loop param/params/params-id/params-id-
break shapes resolved).

### Standing reminder for the autonomous loop

**Project tone is `.claude/rules/no_workaround.md`: fix root
causes, never work around.**

### Next task — D-093 residual sub-clusters

Residual 10 fails on deferred-name out-of-band run:

- **memory.grow JIT skeleton (cluster (a))** — 6 fails:
  nop:as-memory.grow-{first,last,everywhere},
  block:as-memory.grow-value, loop:as-memory.grow-value,
  local_tee:as-memory.grow-size. Needs runtime callout.
- **br_table forward merge** — 2 fails: br_if:nested-br_
  table-value{,-index}. emitBrTable per-case capture-or-MOV
  + variable-disp JNE-skip refactor.
- **validator gap** — 1 fail: if/if.0.wasm StackUnderflow.
- **block:break-inner off-by-one** — 1 fail. Root cause
  unlocalised; d-3-style lower fix regresses realworld.

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
| D-093 (d-6) | [x] (this commit) | Wasm 2.0 block-param multi-value |
| **D-093 residual** | **NEXT** | memory.grow JIT OR br_table merge OR if.0 validator |

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
