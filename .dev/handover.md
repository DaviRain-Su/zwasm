# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -5`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (extended
   2026-05-12 per ADR-0056 — full Wasm 2.0 PASS scope).

## Active state — **Phase 9 EXTENDED scope (ADR-0056); discharging cohort**

§9.11 [x]; §9.10 [~] Phase 11; §9.12 [ ] 🔒 Phase 10 entry gate
(waits for §9.9). **§9.9 [ ] — scope extended to full Wasm 2.0
PASS on Mac+OrbStack per ADR-0056** (2026-05-12). Discoveries:
non-SIMD spec coverage was fake-green (parse+validate only);
~14 JIT op hidden-skip; 30+ non-SIMD + 33 SIMD wasts missing
vs v1 floor; bench script bugs + dead error paths.

Mac+OrbStack SIMD runner 13301/0/440 (bit-identical); D-084
Win64 v128 marshal in flight (worktree agent W).

## Implementation queue (autonomous; order optimised for integration)

Stage A — Foundation:
- 9.9-j-1 **DONE this chunk**: ADR-0056 + ROADMAP §9.9 +
  ADR-0003 Revision history
- **9.9-j-2 NEXT**: test-all wiring (test-edge-cases /
  test-realworld-run-jit / test-wasmtime-misc-runtime) + bench
  script bugs (sci notation parse / stderr capture / schema) +
  `error.UnsupportedImports` dead path
- 9.9-j-3a SKIP allowlist documentation (passive)

Stage B — JIT op completion (小→大):
- 9.9-m-4 select_typed (non-i32)
- 9.9-m-1 ref.null / ref.func / ref.is_null (両 arch)
- 9.9-m-3 memory.init / data.drop / elem.drop (両 arch)
- 9.9-m-2 table.* full 7-op family (両 arch, ~3000 LOC, may
  need ADR-0058 + sub-split)

Stage C — Runner + corpus vendor:
- 9.9-l-1 non-SIMD spec_assert_runner (or wast_runner extend),
  ADR-0057 expected
- 9.9-k-1 Wasm 2.0 non-SIMD wast vendor (~30 files)
- 9.9-k-2 SIMD wast vendor (33 missing files)

Stage D — Cleanup:
- 9.9-n-1 shootout/fib2 perf anomaly investigation
- 9.9-j-3b SKIP gate real enforcement (last; upstream must be
  clean first)

External: **9.9-i-1** Win64 v128 marshal (Agent W, worktree)

## Sandbox quirks + hook scope

- `~/.cache/zig` not write-allowed → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- `p9_simd_status.sh` OrbStack branch fails on daemon log-rotation;
  restart via `pkill -9 -f OrbStack && open -a OrbStack`.
- `scripts/run_remote_windows.sh` fails on `windowsmini.local`
  mDNS intermittently; workaround direct `ssh windowsmini "..."`.
- Per-chunk loop 2-host (Mac+OrbStack) per ADR-0049; windowsmini
  at §9.9 close.

## Open structural debt pointers — see `.dev/debt.md`

- `now`: D-084 (Win64 v128 marshal; Agent W).
- `blocked-by`: D-007/010/016/018/020/021/022/026/028/052/055/
  057/058/059/062/065/072/073/074/075/079(ii)/081/082.

## Investigation reports (gitignored, traceability)

- `private/d084-phase10-scope.md` — Agent (Win64 ABI)
- `private/p9-x-wasm2-non-simd-coverage.md` — Agent X
- `private/p9-y-tests-bench-audit.md` — Agent Y
- `private/p9-z-realworld-v1-parity.md` — Agent Z
