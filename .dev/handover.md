# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -5`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **Phase 9 extended; SEQUENTIAL mode**

§9.11 [x]; §9.10 [~] Phase 11; §9.12 [ ] 🔒 (waits §9.9);
**§9.9 [ ]** scope = full Wasm 2.0 PASS on Mac+OrbStack per
ADR-0056. Mode: SEQUENTIAL (no parallel impl agents).

## Implementation queue

Stage A — Foundation [done]:
- j-1 (`171bbd36`) ADR-0056 scope extension
- j-2 (`a254ba50`) test-all wiring (2/3) + bench fixes
- i-1 (`7a7e387c`) Win64 v128 marshal (Agent W)

Stage B — JIT op completion:
- m-4a [x] (`b620cfcd`) select_typed GPR-types
- m-4b [x] (`9c2644c7`) select_typed f32/f64
- j-2b [x] (`fd9ca8db`) rem_s alias bug (D-085) + edge-cases
  gate (D-086); surfaced D-087/088/089
- **9.9-m-5 NEXT** — x86_64 trap gaps cohort (D-087 trunc, D-088
  div_s, D-089 ld.so) + re-wire test-edge-cases into test-all
- 9.9-m-4c — untyped .select (0x1B) lower-time type inference
- 9.9-m-1 ref.null / ref.func / ref.is_null both arches
- 9.9-m-3 memory.init / data.drop / elem.drop both arches
- 9.9-m-2 table.* full 7-op family (ADR-0058 likely)

Stage C — Runner + corpus vendor:
- 9.9-l-1 non-SIMD spec_assert_runner (ADR-0057)
- 9.9-k-1 Wasm 2.0 non-SIMD wast vendor (~30 files)
- 9.9-k-2 SIMD wast vendor (33 files)

Stage D — Cleanup:
- 9.9-n-1 fib2 perf root cause
- 9.9-j-3b SKIP gate real enforce (last)

## Sandbox quirks + hook scope

- `~/.cache/zig` not write-allowed → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- `p9_simd_status.sh` OrbStack daemon log-rotation panic;
  `pkill -9 -f OrbStack && open -a OrbStack`.
- `scripts/run_remote_windows.sh` `windowsmini.local` mDNS
  intermittently; workaround direct `ssh windowsmini ...`.
- Per-chunk 2-host (Mac+OrbStack) per ADR-0049; windowsmini at
  §9.9 close (Win64 already done via i-1).

## Open debt pointers — see `.dev/debt.md`

- `now`: D-087 (x86_64 trunc trap), D-088 (x86_64 div_s
  overflow trap), D-089 (Linux ld.so dl-fini), filed at j-2b.
- `blocked-by`: D-007/010/016/018/020/021/022/026/028/052(partial)/
  055/057/058/059/062(partial)/065/072/073/074/075/079(ii)/081/082.

## Investigation reports (gitignored)

- `private/d084-phase10-scope.md` — Win64 ABI agent
- `private/p9-x-wasm2-non-simd-coverage.md` — Agent X
- `private/p9-y-tests-bench-audit.md` — Agent Y
- `private/p9-z-realworld-v1-parity.md` — Agent Z
