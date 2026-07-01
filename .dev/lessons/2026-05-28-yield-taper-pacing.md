# Yield-taper pacing: loop needs a soft-surface between non-stop and bucket 3

**Date**: 2026-05-28
**Citing**: session retrospective (post-D-184 close).

## Observation

The `/continue` autonomous loop's stop discipline is binary:
- **Non-stop**: anything not in buckets 1-3 → keep cycling.
- **Bucket 3 stop**: strict — fires only when ALL forward work is
  user-input-gated AND autonomous prep is fully walked.

Between these two, there's a band where:
- Work IS autonomous-doable (so bucket 3 doesn't fire).
- BUT recent chunks are predominantly low-marginal-value
  (test-only regressions, docs, refactors with no behaviour
  delta, lesson writes).
- The cumulative pattern signals a natural pacing-down moment
  that the loop doesn't autonomously recognise.

The user becomes the de-facto circuit breaker because the loop
itself has no "this is enough for one session" sensor.

## Concrete trace (2026-05-28 session)

After the high-yield EH closes (D-181 → D-184), the loop shipped:
- multi-frame cross-frame regression test (low-yield)
- cross-frame + payload integration test (low-yield)
- multi-catch try_table regression (low-yield)
- `code_map.toModuleRelativePc` refactor (low-yield: no behaviour
  delta)
- toModuleRelativePc contract pin test (low-yield)
- handover refresh (low-yield)
- eh_frequency_runner docstring update (low-yield)
- emscripten_eh PROVENANCE refresh (low-yield)

8 consecutive low-yield chunks before the user manually paused.
Each chunk was *individually valuable* (regression coverage,
re-derivability anchors, status accuracy), but the cumulative
pattern was the late-session ramp.

## The discipline added

Yield-aware pacing (LOOP.md new section): at Step 1 (Plan) each
cycle, the loop checks the last 5 commits' yield-class. If ≥4
are low-yield AND the next planned chunk is also low-yield, the
loop writes a **yield-taper note** to handover's
`Open questions / blockers` section.

The note is *information*, not a forced stop. User sees it at
their next check-in and can interrupt or ignore. Loop keeps
re-arming per existing stop discipline.

## Why not a stricter stop

The naive fix would be "after 5 low-yield in a row, force stop".
Rejected because:
- Low-yield chunks ARE legitimate (regression coverage, lesson
  capture, etc.). Force-stopping would lose them.
- The user's circuit-breaker role is intentional — they have
  context about which area to pivot to that the loop doesn't.
- A surface-to-user soft signal preserves user agency while
  removing the friction (re-deriving state from git log).

## What this is NOT

- NOT bucket 3 — bucket 3 stays strict (all forward work
  user-gated).
- NOT a forbidden `handover_doc_discipline.md` §1 phrase — the
  note names a testable observation (last 5 commit yield-counts)
  plus a concrete pivot candidate.
- NOT a workaround per `no_workaround.md` — it's an information
  surface, not a paper-over.

## Stale-ness

If yield-class taxonomy proves wrong (e.g., a "refactor with no
behaviour delta" turns out to be load-bearing), refine the table
in LOOP.md's "Yield class" section. The 4/5 threshold is
heuristic; sharpen if empirically too lax or too tight.

## Related

- `.claude/skills/continue/LOOP.md` (the discipline)
- `.claude/skills/continue/STOP_BUCKETS.md` (strict bucket 3 —
  unchanged by this addition)
- `.dev/decisions/0118_meta_loop_consolidation.md` (Revision
  history row 2026-05-28 documents this addition)
- `.claude/rules/handover_doc_discipline.md` §1 (forbidden
  surrender phrases — the yield-taper note's shape is compatible
  by construction)
