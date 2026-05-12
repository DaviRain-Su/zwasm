# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **Phase 9 extended; D-092 discharged 2026-05-12**

### One-line state

D-092 closed: x86_64 `emitFpMinMax` now handles regalloc's
`dst == rhs and dst != lhs` slot shape via commutative swap
(mirrors `emitFpBinary`; min/max are commutative across all
three branches — UCOMI / MINSS-MAXSS / ORPS-ANDPS / ADDSS).
Mac + OrbStack `test-spec-wasm-2.0-assert`: **11540 / 0 /
106 bit-identical** (skip_text_format_parser only). f32 /
f64 re-enabled in `scripts/regen_spec_2_0_assert.sh` NAMES.
simd_assert 13301/0/440 + spec_assert 212/0/20 unchanged.
Co-discharged: orphan `skip_x86_64_trunc_precision.md` ADR
(Superseded since D-091 close, silently failing
`check_skip_adrs --gate`) deleted; dead `TRUNC_TRAP_OPS`
python helper purged from regen script.

### Standing reminder for the autonomous loop

**Project tone is `.claude/rules/no_workaround.md`: fix root
causes, never work around.** See
`.dev/lessons/2026-05-12-loop-defers-over-fixes-when-cost-high.md`.
On the next chunk's first obstacle, walk
`extended_challenge.md` Step 1 BEFORE reaching for a filter /
fallback / skip-ADR.

### Next task — k-1-expand-2

Continue the spec_assert_runner_non_simd corpus expansion: add
the next batch of wasm-2.0 wast names to NAMES in
`scripts/regen_spec_2_0_assert.sh`, regen, run, address any new
dispatch-shape gaps. Candidates (not yet in NAMES, from upstream
`WebAssembly/spec/test/core/`): `address`, `align`, `block`,
`br`, `br_if`, `br_table`, `call`, `call_indirect`, `const`,
`data`, `elem`, `f32_bitwise`, `f64_bitwise`, `fac`, `func`,
`func_ptrs`, `global`, `if`, `labels`, `load`, `local_get`,
`local_set`, `local_tee`, `loop`, `memory`, `memory_grow`,
`memory_size`, `nop`, `return`, `select`, `start`, `store`,
`switch`, `table`, `traps`, `type`, `unreachable`, `unwind`.
Bundle ~5–15 names per chunk per LOOP "Chunk granularity".

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
| D-092-close | [x] 520246cd | x86_64 emitFpMinMax dst==rhs swap; f32+f64 in NAMES |
| **k-1-expand-2** | **NEXT** | next batch of wasm-2.0 wast names |

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

- `now`: none (D-091 + D-092 discharged).
- `blocked-by`: D-007/010/016/018/020/021/022/026/028/052(partial)/
  055/057/058/059/062(partial)/065/072/073/074/075/079(ii)/
  081/082/090.

## Reference chain

- `.dev/decisions/0057_spec_assert_runner_factoring.md` — Option B.
- `.dev/decisions/0058_table_ops_jit_design.md` — m-2 cluster.
- `private/notes/p9-99-l-1-spec-assert-survey.md` — factoring survey.
- `private/p9-close-next-session-pickup.md` — broader queue context.
