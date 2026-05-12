# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **Phase 9 extended; 9 chunks landed this session**

§9.11 [x]; §9.10 [~] Phase 11; §9.12 [ ] 🔒 (waits §9.9);
**§9.9 [ ]** scope = full Wasm 2.0 PASS on Mac+OrbStack per
ADR-0056. test-edge-cases 35/0 both hosts; SIMD 13301/0/440
bit-identical Mac+OrbStack (+ windowsmini via Agent W);
non-SIMD spec wast runtime gate still pending (l-1 + k-1).

## Implementation queue (sequential)

Landed [x] this session (Stage A + Stage B partial):
- j-1 ADR-0056 scope
- j-2 test-all 2/3 wirings + bench bugs
- i-1 Win64 v128 marshal (Agent W)
- m-4a/b select_typed (GPR + f32/f64)
- j-2b rem_s alias + edge-cases gate
- m-5 x86_64 trap-stub R15 prescan (D-087/088/089 single fix)
- m-1a ref.null + ref.is_null
- m-1b ref.func + JitRuntime func_entities extension

Pending [ ] (sequential):
- **9.9-m-3 NEXT** — memory.init / data.drop / elem.drop. Each
  needs JitRuntime extension for data_segments / elem_segments
  base ptr + length + dropped flag table. Similar pattern to
  m-1b's func_entities extension.
- 9.9-m-2 table.* full 7-op family — biggest (~3000 LOC per
  Agent X); ADR-0058 likely. Tables: get/set/size/grow/fill/
  copy/init.
- 9.9-m-4c untyped `.select` lower-time type inference.
- 9.9-l-1 non-SIMD spec_assert_runner (ADR-0057).
- 9.9-k-1 / k-2 wast vendor (~30 + 33 files from upstream
  WebAssembly/spec/test/core).
- 9.9-n-1 fib2 41-second perf root cause.
- 9.9-j-3b SKIP gate real enforcement (last).

## Sandbox quirks + hook scope

- `~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- OrbStack daemon log-rotation panic — restart via
  `pkill -9 -f OrbStack && open -a OrbStack`.
- `scripts/run_remote_windows.sh` mDNS flake — direct
  `ssh windowsmini ...` works.
- Per-chunk 2-host (Mac+OrbStack) per ADR-0049.

## Open debt — see `.dev/debt.md`

- `now`: none (D-084/085/086/087/088/089 discharged today).
- `blocked-by`: D-007/010/016/018/020/021/022/026/028/052(partial)/
  055/057/058/059/062(partial)/065/072/073/074/075/079(ii)/
  081/082.

## Investigation reports (gitignored)

- `private/d084-phase10-scope.md` — Win64 ABI
- `private/p9-x-wasm2-non-simd-coverage.md` — Agent X
- `private/p9-y-tests-bench-audit.md` — Agent Y
- `private/p9-z-realworld-v1-parity.md` — Agent Z
