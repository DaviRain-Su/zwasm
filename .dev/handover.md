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

## Active state — **Phase 9 extended; m-3b landed 2026-05-12**

§9.11 [x]; §9.10 [~] Phase 11; §9.12 [ ] 🔒 (waits §9.9);
**§9.9 [ ]** scope = full Wasm 2.0 PASS on Mac+OrbStack per
ADR-0056. m-3b adds JIT `memory.init` end-to-end (3rd-gen
JitRuntime ABI extension: `SegmentSlice` + `data_segments_ptr`).
Mac aarch64 test-all green incl. 5 new edge_cases fixtures
(init_happy/n_zero/oob_src/oob_dst/dropped); OrbStack
reconciles on this commit. Live counts in
`bash scripts/p9_simd_status.sh`.

11 chunks landed across the prior session + this session
(see pickup doc §"Landed" + this commit). 7 debt rows
discharged across the same window.
2 ADRs (ADR-0055, ADR-0056) accepted. ADR-0003 amended.

## Implementation queue (sequential — pickup detail in pickup doc)

Next session picks up at **m-2**. Order:

1. **m-2 NEXT** — table.* full 7-op family. Likely ADR-0058
   scope. Split candidate (m-2a/b/c per pickup doc §"m-2").
2. m-4c — untyped .select (0x1B) lower-time type inference.
3. l-1 — non-SIMD spec_assert_runner. ADR-0057 expected.
4. k-1 — Wasm 2.0 non-SIMD wast vendor (~30 files).
5. k-2 — SIMD wast vendor (33 files).
6. n-1 — fib2 perf root cause.
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

TaskList state in CLI mirrors this queue (#21-#26 pending +
#30 m-3b + #31 m-4c).
