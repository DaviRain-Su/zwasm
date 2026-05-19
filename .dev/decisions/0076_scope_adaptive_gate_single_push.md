# 0076 — Scope-adaptive per-chunk gate + single-push cycle + deferred ubuntu verification

- **Status**: Accepted
- **Date**: 2026-05-19
- **Author**: Shota Kudo
- **Tags**: process, loop, gate

## Context

Two cost observations from the §9.12-B autonomous loop:

1. **`zig build test-all` is the unconditional per-chunk gate.** B53
   (substrate-only — new `EmitCtx` struct + inert init, no fn body
   change) spent ~10 minutes on ubuntu `test-all` exercising no new
   behaviour. The B53 / B54 cycle pair spent more wall-clock on
   ubuntu test waits than on every other step combined.
2. **Per-chunk pipeline is serial.** Today's order is
   Mac test → source commit → push → **ubuntu test wait** →
   handover commit → push (= 2 pushes per chunk; the loop is pinned
   to ubuntu's wall-clock; bench-CI bot lands a `bench(ci): record`
   commit between the two pushes, forcing a rebase per chunk).

§9.12-B has ~70 remaining chunks; the cost compounds.

## Decision

Adopt three coupled disciplines for the autonomous loop. None of them
relaxes spec conformance — they reorder when verification happens, not
what gets verified.

### D1 — Scope-adaptive gate

Chunk scope is mechanically classified by
`scripts/classify_chunk_scope.sh`, which reads `git diff --stat HEAD`
+ `git diff HEAD` and prints one of:

| Class       | Gate             | Trigger heuristic                                                       |
|-------------|------------------|-------------------------------------------------------------------------|
| `substrate` | `zig build test` | New / changed files are struct defs + init sites + imports only         |
| `logic`     | `zig build test-all` | New `pub fn emit*` / dispatch arm change / new per-op file under `ops/` |
| `cohort`    | `zig build test-all` | ≥ 5 ops touched (file count under `ops/*` directory)                    |
| `unclear`   | `zig build test-all` (default) | The above heuristics didn't fire; safe fallback              |

LOOP.md does **not** maintain the judgement table in prose — the
script *is* the rule (mirroring `gate_commit.sh` / `zone_check.sh` /
`file_size_check.sh`). When the heuristic needs updating (new file
shape, new layer), the script is the single edit site.

### D2 — Single-push cycle

Source commit and handover commit land back-to-back locally, then
**one** `pull --rebase --autostash + push` fires. The bench-CI bot's
`bench(ci): record <sha>` commit gets rebased exactly once per chunk
instead of twice.

### D3 — Deferred ubuntu verification

ubuntu test starts in `run_in_background` **after** the push (= against
the just-pushed commit) and is **not** waited on by the current
cycle. The result is verified at the next cycle's Resume Procedure
Step 5c — a mechanical `tail -3 /tmp/ubuntu.log` check for the
`[run_remote_ubuntu] OK (HEAD=<sha>)` line whose SHA matches
`HEAD~1`. If the prior cycle's ubuntu FAILed, the current cycle
reverts the last 2 commits (`git reset --mixed HEAD~2`), preserves
the diff in the worktree, and switches to fix mode.

The verification deferral is **one chunk** wide — the loop never
gets more than one chunk ahead of ubuntu.

## Alternatives considered

### Alternative A — Keep test-all per chunk

Status-quo. Rejected: §9.12-B has ~70 remaining chunks × ~10 min
ubuntu test-all = ≈11.6 h pure ubuntu wait. Even a 50% scope-adaptive
hit rate saves ≈5.8 h.

### Alternative B — Skip ubuntu entirely on substrate chunks

Tempting (substrate bugs would surface on Mac `test`). Rejected:
ubuntu catches x86_64-specific issues that Mac aarch64 can't see
(stack alignment off-by-N, x86_64 codegen miscompile, OS-specific
syscall numbers). Substrate chunks legitimately need ubuntu — they
just don't need `-spec` / `-realworld` corpora on top of `test`.

### Alternative C — Branch per chunk + verify on PR

Incompatible with the autonomous-loop model. Rejected.

### Alternative D — Block on ubuntu before next chunk's Step 0

Status-quo's gating discipline. Rejected: the cost item (1) is
exactly the wall-clock penalty of this block.

## Consequences

### Positive

- Substrate / refactor chunks land ~5x faster (≈2 min vs ≈10 min).
- Push count halves; rebase-against-bench-bot incidence halves.
- ubuntu wait becomes background; the loop starts the next chunk's
  Step 0 immediately after push.
- The `classify_chunk_scope.sh` heuristic is single-site-editable;
  per-class behaviour evolves without LOOP.md prose churn.

### Negative

- Step 5c FAIL means reverting 2 commits (source + handover). Handled
  by `git reset --mixed HEAD~2` + re-staging.
- ubuntu-deferred-verification means a failing chunk lands on origin
  briefly (≈1 chunk window). The `zwasm-from-scratch` branch is the
  development branch (push is autonomous; no PR gate); the merge gate
  (`scripts/gate_merge.sh` per CLAUDE.md "Pre-commit gate") still
  blocks any `main` push on the strict 3-host `test-all`.
- `classify_chunk_scope.sh` maintenance burden: new file shapes need
  heuristic updates. The default fallback (`test-all`) absorbs slips
  safely.

### Neutral / follow-ups

- ADR-0049 (windowsmini per-chunk defer) was the spiritual predecessor:
  this ADR generalises that policy to ubuntu-and-Mac scope. The
  windowsmini phase-boundary reconciliation is unchanged.
- The "1 chunk lookahead" window is conservative. A larger window
  (= the loop runs N chunks ahead of ubuntu) is technically possible
  but rejected for now: revert depth = N is more painful to recover
  from on FAIL.

## Implementation

| Artifact                                                      | Change                                                                                      |
|---------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `scripts/classify_chunk_scope.sh` (new)                       | `git diff --stat HEAD` + heuristics → prints `substrate` / `logic` / `cohort` / `unclear`   |
| `.claude/skills/continue/SKILL.md` Resume Step 5c (new)       | Mechanical `tail -3 /tmp/ubuntu.log` check + `git reset` on FAIL                            |
| `.claude/skills/continue/SKILL.md` TDD Step 5                 | Pick scope via `scripts/classify_chunk_scope.sh`; map to gate command                       |
| `.claude/skills/continue/SKILL.md` TDD Step 6 + Step 7        | Merge into single source-then-handover commit pair; single push; ubuntu bg                  |
| `.claude/skills/continue/LOOP.md` "Parallel test gate"        | Rewrite to match D2 + D3                                                                    |

## References

- `.claude/skills/continue/LOOP.md` §"Parallel test gate" — rewritten
- `.claude/skills/continue/SKILL.md` §"Resume procedure" Step 5c — new
- `.claude/skills/continue/SKILL.md` §"Per-task TDD loop" Step 5 — adapted
- ADR-0049 — windowsmini per-chunk defer (spiritual predecessor)
- ADR-0067 — ubuntunote pivot (sets the substrate this ADR builds on)
- §9.12-B / B53 + B54 retrospective (the 2026-05-19 session that
  surfaced the cost)

## Revision history

| Date       | SHA          | Note                       |
|------------|--------------|----------------------------|
| 2026-05-19 | `<backfill>` | Initial accepted version.  |
