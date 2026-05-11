# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -5`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
   Authoritative; trust the script if anything disagrees.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row.

## Active state — **PHASE 10 PREP CLOSED ✅**

Prep mode complete 2026-05-11..2026-05-12; 4 tracks decided.
Deliverables: `.dev/phase10_prep/track_{a,b,c}_*.md` +
`.dev/phase10_transition_gate.md`. Normal `/continue` resumes.

Phase: 9 (SIMD-128). §9.5/6/7/8 [x]; §9.9 [ ] (Mac+OrbStack
11384/0 post-h-14; SKIP=2357; windowsmini reconcile pending).

Latest landed: `cf7d02da` — 9.9-h-18 arm64 op_simd.zig 4-way
source split (Track B chunk 4/6, mirrors x86_64 9.9-h-15 via
Option A call-site updates); next chunk `9.9-h-19`.

## Implementation queue (matches ROADMAP first `[ ]`)

§9.9 sub-chunks h-15..-N until skip-impl=0; then §9.11 (bundling
Track A's §9.10 reshape); then §9.12 + Track D wiring; then hard
gate. Specs: `phase10_prep/track_*.md` §6/§7.

1. **Track B** (9.9-h-15..-20, 6 chunks): 4-way source split +
   4-way test mirror (`_test.zig` suffix) + 3-way encoder
   split + ADR-0054 + tiered pub + file_size_check warn→gate
   + D-081 file + D-057/D-065 close.
   - **9.9-h-15** `[x]` `280617d9` — x86_64 op_simd source 4-way.
   - **9.9-h-16** `[x]` `155afd58` — op_simd_test 4-way mirror
     + transitional re-exports removed.
   - **9.9-h-17** `[x]` `e790d2c4` — inst_sse 3-way encoder split.
   - **9.9-h-18** `[x]` `cf7d02da` — arm64 op_simd 4-way split
     (no inline tests in arm64 op_simd.zig — no test mirror).
   - **9.9-h-19** **NEXT** — arm64 `inst_neon.zig` (2323 LOC)
     3-way encoder split → `inst_neon` (foundation: mem/reg-move)
     + `inst_neon_arith` (arith) + `inst_neon_lane_cmp`
     (lane + cmp). Last hard-cap exceeder.
   - **9.9-h-20** — Track B chunk 6/6: flip file_size_check
     warn→gate; remove warn note from gate_commit.sh; close
     D-057 + D-065; file D-081 (legacy emit_test_* rename).
2. **Track C** (9.9-h-21..-24, 4 chunks): Path B prefix-vocab
   migration → ADR-0029 amend + check_skip_adrs.sh pre-commit
   gate + D-082 file + D-072 (a/b) + D-073 close.
3. **§9.9 close residual** (h-25..-N, count TBD by live
   status post-Track-C): `p9_simd_status.sh` surfaces
   `skip-impl` count (currently ~1967 = nan-or-bad-token 1222
   + v128-param-pending 788 + assert_trap-v128 18 +
   export-name 3). Loop picks largest category per resume;
   chunks until `failed=skip-impl=0` on 2-host; windowsmini
   reconcile at Phase boundary close. §9.9 row flips `[x]`.
4. **§9.11 + Track A bundled** (1 chunk): audit_scaffolding
   Phase-9 pass + SHA backfill §9.9 `[x]` rows + §9.10
   `[~] moved to Phase 11` + Phase 11 row prose + ADR-0043
   amend + D-074 update + D-076 close.
5. **§9.12 + Track D wiring** (1 chunk): §9.12 row text →
   `🔒 Phase 10 entry gate review
   (.dev/phase10_transition_gate.md)`; add Phase 9→10 entry
   to SKILL.md "Currently registered hard gates" list.
6. **Phase 10 entry HARD GATE STOP** — next resume after §9.12
   wiring lands hits the row, detector fires, loop surfaces
   `phase10_transition_gate.md` for collaborative review. No
   `ScheduleWakeup`.

## Phase 10 design ADR slots (Track D §9 Q3)

ADR-0054 = Track B; A amends ADR-0043; C amends ADR-0029.
Phase 10 per-subsystem (Q2 order): ADR-0055 memory64 →
0056 Tail Call → 0057 EH → 0058 WasmGC.

## Open structural debt (pointers — see `.dev/debt.md`)

- `now`: none post-§9.9-h-14.
- `blocked-by`: D-007/010/016/018/020/021/022/026/028/052/055/
  D-057/058/059/062/D-065/D-072/D-073/D-074/075/D-076/D-079(ii).
  Prep impl discharges **D-057 / D-065 / D-072 (a/b) / D-073 /
  D-076**; D-074 updated; **D-081 / D-082** newly filed.

## Sandbox quirks + hook scope

- `~/.cache/zig` not write-allowed → prefix `zig build*` with
  `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- `p9_simd_status.sh` OrbStack branch fails on daemon log-rotation;
  use top-level `orb run -m my-ubuntu-amd64 bash -c '...'` directly.
- `.githooks/pre-push` → `gate_commit.sh` (light); full 3-host
  `gate_merge.sh` manual at Phase boundary + before push to main.
  Per-chunk loop is 2-host (Mac+OrbStack) per ADR-0049;
  windowsmini phase-boundary only.
