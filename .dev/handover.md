# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).
5. **Read `private/p9-close-next-session-pickup.md`** — full
   per-chunk pickup chain (recipes, file paths, ADR notes) for
   the queue below. Authoritative for next session continuation.

## Active state — **Phase 9 extended; m-2 base scope landed 2026-05-12**

§9.11 [x]; §9.10 [~] Phase 11; §9.12 [ ] 🔒 (waits §9.9);
**§9.9 [ ]** scope = full Wasm 2.0 PASS on Mac+OrbStack per
ADR-0056. m-2 cluster base scope (a + b + c + c-init) landed
this session: JIT `table.get` / `table.set` / `table.size` /
`table.fill` / `table.copy` / `table.init` both arches per
ADR-0058 (+ amendment). JitRuntime ABI extended with TableSlice
+ ElemSlice (head_size 152 → 184 bytes). 18 new p9/table_ops
edge_cases fixtures (size_initial / get_null_funcref /
set_get_roundtrip / get_oob / set_oob / fill_happy / fill_oob /
fill_n_zero / copy_same_table_forward / copy_same_table_backward /
copy_cross_table / copy_oob_dst / copy_oob_src / init_happy /
init_oob_dst / init_oob_src / init_dropped / init_n_zero). Live
counts in `bash scripts/p9_simd_status.sh`.

16 chunks landed across the §9.9 close window so far. 7 debt
rows discharged. 3 ADRs (ADR-0055, ADR-0056, ADR-0058 + 1
amendment) accepted; ADR-0003 amended; ADR-0017 implicit
Revision extensions x6 (m-1a, m-1b, m-3a, m-3b, m-2a TableSlice,
m-2c-init ElemSlice).

## Implementation queue (sequential — pickup detail in pickup doc)

Next session picks up at **l-1a** (survey done this session;
see `private/notes/p9-99-l-1-spec-assert-survey.md`).
ADR-0057 design = Option B (base + specialisations). Order:

1. **l-1a NEXT** — extract `spec_assert_runner_base.zig` from
   simd_assert_runner.zig (1071 LOC → ~550 base + ~500 SIMD).
   Pure refactor; RunnerCallbacks trait pattern; SIMD test
   gate stays at 13301/0/440 verifies. File ADR-0057 in
   same commit per §18.2.
2. l-1b — new `spec_assert_runner_non_simd.zig` (~450 LOC) +
   new `test-spec-wasm-2.0-assert` build step + curated
   wasm-2.0 non-SIMD corpus.
2. k-1 — Wasm 2.0 non-SIMD wast vendor (~30 files).
3. k-2 — SIMD wast vendor (33 files).
4. m-4c (= D-090) — untyped .select non-i32 type inference.
   Needs lower.zig type-stack walker mirroring the validator's
   per-op type tracking. Filed as debt D-090 with concrete
   discharge plan.
5. m-2d — table.grow JIT with allocator-helper infrastructure.
   Last piece of the m-2 cluster; needs `*const Allocator`
   surfacing into JitRuntime via opaque-state pointer + helper
   function pointer.
6. n-1 — fib2 perf root cause (22KB Rust-WASI binary; 41s/run
   on Mac). Requires JIT profiling infra; investigation chunk.
7. j-3b — SKIP gate real enforcement (last).

## Sandbox quirks + hook scope

- `~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- OrbStack daemon log-rotation panic — restart via
  `pkill -9 -f OrbStack && open -a OrbStack`.
- `scripts/run_remote_windows.sh` mDNS flake — direct
  `ssh windowsmini ...` works.
- Per-chunk 2-host (Mac+OrbStack) per ADR-0049; windowsmini
  reconcile only at §9.9 close (Win64 already done via i-1).

## Open debt — see `.dev/debt.md`

- `now`: none (7 discharged this session).
- `blocked-by`: D-007/010/016/018/020/021/022/026/028/052(partial)/
  055/057/058/059/062(partial)/065/072/073/074/075/079(ii)/
  081/082.

## Reference chain for next /continue

- `private/p9-close-next-session-pickup.md` — **read first**
  on next session. Per-chunk recipes, file paths, design notes,
  edge cases, test fixture suggestions.
- `private/d084-phase10-scope.md` — Win64 ABI agent (history).
- `private/p9-x-wasm2-non-simd-coverage.md` — coverage audit.
- `private/p9-y-tests-bench-audit.md` — bench/tests audit.
- `private/p9-z-realworld-v1-parity.md` — realworld + v1 parity.

TaskList state in CLI mirrors this queue (#5 m-2d + new m-4c
pending; #2/#3/#4/#6 m-2a/b/c/c-init completed).
