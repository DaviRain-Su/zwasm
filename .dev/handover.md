# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -5`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
   Authoritative; trust the script if anything disagrees.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9 task table.

## Active state — **Phase 9 closing, §9.11 LANDED**

Phase: 9 (SIMD-128). §9.5/6/7/8 [x]; §9.9 [ ] (skip-impl=0 met,
2-host bit-identical; flips at Phase boundary close after
windowsmini reconcile); §9.10 [~] **moved to Phase 11** per
Track A Option (3); §9.11 [x] this chunk; §9.12 [ ] next.

Track A migration (this chunk): ADR-0043 amended (§"Decision"
+ §"Migration history" + §"Amendment log" 2026-05-12 row);
ROADMAP §9.10 row → `[~] moved to Phase 11`; Phase 11 row
exit-criterion gains SIMD per-op gap analysis bullet (with the
3× threshold, D122 ref, AVX/MOVAPS/coalescing candidate list
intact); Phase Status widget Phase 11 line annotated; Phase 15
narrative cite-refs `§9.10` → `Phase 11`. D-076 discharged;
D-074 barrier updated to name SIMD-perf as additional
Phase 11 carrier. audit_scaffolding ran (3 block / 8 soon /
6 watch); top block was handover length+contradiction, fixed
by this rewrite.

## Implementation queue (matches ROADMAP first `[ ]`)

§9.12 next; then Phase 10 entry HARD GATE STOP.

1. **§9.12 + Track D wiring** (1 chunk): retarget §9.12 row
   text from `Open §9.10 inline + flip phase tracker` to
   `🔒 Phase 10 entry gate review (.dev/phase10_transition_
   gate.md)`. Add Phase 9→10 hard-gate entry to
   `.claude/skills/continue/SKILL.md` "Currently registered
   hard gates" list. Run windowsmini phase-boundary reconcile
   (`bash scripts/run_remote_windows.sh test-spec-simd`);
   if green, §9.9 row flips `[x]` in same chunk. §9.12 row
   itself flips `[x]` at commit-time.
2. **Phase 10 entry HARD GATE STOP** — next resume after
   §9.12 wiring lands hits the row, detector fires, loop
   surfaces `phase10_transition_gate.md` for collaborative
   review. No `ScheduleWakeup`; bucket-1 user-intervention
   stop.

## Phase 10 design ADR slots (Track D §9 Q3)

ADR-0054 = Track B; ADR-0043 amended (Track A migration);
ADR-0029 amended (Track C). Phase 10 per-subsystem (Q2 order):
ADR-0055 memory64 → 0056 Tail Call → 0057 EH → 0058 WasmGC.

## Open structural debt (pointers — see `.dev/debt.md`)

- `now`: none.
- `blocked-by`: D-007/010/016/018/020/021/022/026/028/052/055/
  D-057/058/059/062/D-065/D-072/D-073/D-074(updated)/075/
  D-079(ii)/081/082. D-076 discharged this chunk.

## Sandbox quirks + hook scope

- `~/.cache/zig` not write-allowed → prefix `zig build*` with
  `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- `p9_simd_status.sh` OrbStack branch fails on daemon log-
  rotation; restart via `pkill -9 -f OrbStack && open -a
  OrbStack`, then top-level `orb run -m my-ubuntu-amd64
  bash -c '...'` directly.
- `.githooks/pre-push` → `gate_commit.sh` (light); full 3-host
  `gate_merge.sh` manual at Phase boundary + before push to
  main. Per-chunk loop is 2-host (Mac+OrbStack) per ADR-0049;
  windowsmini phase-boundary only (§9.12 chunk fires it).
