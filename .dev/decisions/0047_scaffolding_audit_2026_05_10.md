---
name: Scaffolding audit (2026-05-10) — auto-load trigger pruning + redundancy reduction
description: Apply the small-fix subset of the 2026-05-10 scaffolding audit (markdown_format paths, textbook_survey paths, SKILL.md non-stop grouping, lessons_vs_adr framing); preserves all load-bearing rules.
status: Accepted
date: 2026-05-10
---

# ADR-0047: Scaffolding audit (2026-05-10) — auto-load trigger pruning + redundancy reduction

## Status

Accepted (2026-05-10) — subagent self-review confirmed no
load-bearing rule was lost, all gates preserved, frontmatter
paths now aligned with rule body scope.

## Context

User request at the §9.9-c → §9.9-d boundary: the autonomous loop
has been accumulating scaffolding (rules, skills, output styles)
across the Phase 9 run, and context-window / weekly-rate-limit
pressure plus measurable performance degradation at high context
fill warranted a deliberate audit + cleanup pass.

A read-only Explore subagent ran the full
`audit_scaffolding`-style sweep across `.claude/`, `CLAUDE.md`,
`.dev/handover.md`, `.dev/debt.md`, `.dev/lessons/INDEX.md`,
`.dev/decisions/README.md`. Output: 4297 lines across 18 markdown
+ JSON files; report at `/tmp/scaffolding-audit-2026-05-10.md`.

The audit's headline finding: **scaffolding integrity is high**;
total potential savings ~65 LOC redundancy + 1500 bytes of
duplicate procedure prose (DUP-2 already addressed in the same
session). Three of the seven proposed actions were verified false
positives on inspection:

- DUP-1 (Step 0.5 in CLAUDE.md) — CLAUDE.md already a one-line
  pointer to SKILL.md; not a real duplicate.
- DUP-2 (Three-host gate in SKILL.md vs LOOP.md) — earlier
  session's "Parallel test gate" centralisation already moved
  the canonical procedure to LOOP.md; SKILL.md cites it.
- Quick-win #3 (D-057 ADR-0030 reference) — `ls .dev/decisions/`
  confirms `0030_x86_64_emit_test_split.md` exists. The audit
  subagent was misled by "Phase 9 ADRs are 0041-0046" without
  noticing D-057's reference is to ADR-0030 as the *precedent
  pattern*, not as a Phase 9 ADR.

The remaining four actions are all small, low-risk, and target
real auto-load / redundancy issues.

## Decision

Apply four targeted edits in a single commit:

**A. `markdown_format.md` paths — add `.claude/**/*.md`.**
Currently the rule auto-loads on `.dev/**/*.md` + `docs/**/*.md`
+ `README.md` + `CLAUDE.md`. Edits to rule files themselves
(`.claude/rules/*.md`, `.claude/skills/**/*.md`) routinely involve
markdown formatting (tables, list bullets, frontmatter), so the
rule should fire there too. **One-line addition.**

**B. `textbook_survey.md` paths — remove `.dev/ROADMAP.md` and
`.dev/handover.md`.** The rule body explicitly opens with
"Auto-loaded when editing Zig sources" — survey discipline is a
code-level concern (Step 0 of the per-task TDD loop). ROADMAP /
handover edits are status-tracking, not implementation; the rule
firing on those edits is noise. **Two-line deletion in
frontmatter.**

**C. `continue/SKILL.md` "Non-stop conditions" — group 14 bullets
into 3 named categories.** Current shape is a flat list of every
conceivable non-stop trigger; reorganising into "Phase &
boundary" / "Delegation & autonomous mechanics" / "User &
silence" preserves every existing rule and improves readability
without losing exhaustiveness. **No rule deletion; structural
re-grouping only.** Estimated saving ~10 LOC.

**D. `lessons_vs_adr.md` "What ADRs / What lessons" — collapse
into one tighter section.** The TL;DR table at the file's top
already encodes the role distinction. The two prose sections add
useful examples but re-state the role boundary verbosely. Merge
into a single "Roles, with concrete examples" subsection that
keeps every example bullet (load-bearing for the citation
lineage) while dropping the repeated framing. Estimated saving
~20-30 LOC.

## Alternatives

### A1. Do nothing

The audit headline says integrity is high; ~65 LOC across 4300
is ~1.5% reduction. Rejected because: (1) the user explicitly
requested the cleanup citing weekly rate-limit pressure +
performance degradation at high context fill, (2) auto-load
trigger inaccuracy (B's textbook_survey firing on doc edits) is
a real cost that compounds across every loop iteration that
edits ROADMAP / handover, (3) "small wins" auditing is cheaper
than letting drift accumulate to Phase-boundary scale.

### A2. Apply all 7 audit actions (including the false positives)

Rejected on inspection: D-057 reference is correct (ADR-0030
exists); DUP-1 is already a pointer not a duplicate; DUP-2 was
addressed in the same session. Acting on false positives would
introduce churn without benefit and risk dropping correct text.

### A3. Aggressive consolidation (merge SKILL.md + LOOP.md, etc.)

Rejected. The SKILL.md / LOOP.md split exists because LOOP.md
loads once per session (canonical procedures that don't change
between iterations); SKILL.md is the active-loop entry point.
Merging would defeat that separation and bloat the per-task
context load.

## Consequences

### Positive

- Auto-load triggers more accurately reflect rule scope: edits to
  `.dev/ROADMAP.md` no longer pull in textbook_survey.md (227
  lines of code-survey discipline irrelevant to the edit);
  markdown edits inside `.claude/` finally pull in the
  formatting rule.
- continue/SKILL.md Non-stop conditions become categorical and
  scannable; loops that read this section every iteration save
  context recall cost.
- lessons_vs_adr.md tightens around its TL;DR table without
  losing example links.
- Net ~30-40 LOC reduction across the four files; not large but
  every line trimmed is a line not paid on every auto-load.

### Negative

- ADR-0047 itself adds ~150 lines to `.dev/decisions/`. Rationale:
  the cleanup pass is small enough that an ADR's overhead per
  the `lessons_vs_adr.md` decision tree is borderline; chose ADR
  over lesson because the auto-load trigger changes (A, B) are
  load-bearing in the strict sense — they alter which rules
  fire when and would be invisible to readers without a
  Decision-grade record.
- A subsequent audit may want to re-add `.dev/ROADMAP.md` to
  textbook_survey.md if survey discipline becomes
  ROADMAP-relevant (e.g. ROADMAP §9 row gains code-cite gates).
  Revisit at Phase 10 boundary; for now, the rule body's "Zig
  sources" framing is authoritative.

### Removal condition

Revisit at the Phase 10 boundary `audit_scaffolding` invocation,
or sooner if a future cycle's scaffolding feels off. The four
edits are individually reversible; this ADR documents *why* they
were applied so future audits don't undo them blindly thinking
they're churn.

## Self-review (subagent, 2026-05-10)

An independent Explore subagent re-read the four edited files +
this ADR + the original audit report at
`/tmp/scaffolding-audit-2026-05-10.md`, with no edit privileges,
and produced `/tmp/scaffolding-self-review-2026-05-10.md`.

### Load-bearing preservation

- **continue/SKILL.md Non-stop conditions**: a 14-row mapping
  table verified each original bullet maps onto the new 3-
  category structure (Phase / Delegation / User signal). One
  previously-implicit rule ("only an explicit user message
  stops") is now explicit; this is *clarification, not
  deletion*. ✓
- **lessons_vs_adr.md**: all 5 ADR examples + 2 lesson examples
  + every prescriptive descriptor preserved across the prose
  consolidation. The 14 LOC saved came from removing repeated
  framing text, not content. ✓
- **frontmatter paths vs body**: both edited rules now match
  their "Auto-loaded when..." text — markdown_format covers
  every markdown directory it claims to (now including
  `.claude/**/*.md`); textbook_survey covers only the Zig
  sources it claims to (no longer firing on doc edits). ✓

### Gate preservation

3-host test gate (canonical in LOOP.md), pre-commit gates
(zone_check / file_size_check / spill_aware_check / lint), Push
policy, Phase-boundary `audit_scaffolding` cadence — none touched
by the four edits, all wording intact in their canonical
locations. ✓

### Audit miscall investigation

The three audit false positives dropped at draft time were
re-verified independently:

- **DUP-1** (Step 0.5 in CLAUDE.md): grep confirms CLAUDE.md
  carries a one-line pointer, not a duplicate procedure.
- **DUP-2** (3-host gate in SKILL.md): SKILL.md already cites
  LOOP.md's canonical procedure; no duplicate body.
- **D-057 → ADR-0030**: file `0030_x86_64_emit_test_split.md`
  exists; D-057 cites it as a precedent pattern, correctly.

### Delegation opportunities (deferred follow-ups)

The review surfaced 2 delegation candidates worth tracking but
not blocking this commit:

1. **`scripts/check_rule_paths.sh`** — lint that grep's each
   rule's "Auto-loaded when editing X" body line against its
   `paths:` frontmatter, flagging drift. Would have caught the
   textbook_survey misalignment automatically. Filed as a debt
   candidate at the next sweep.
2. **`scripts/check_skill_descriptions.sh`** — measure each
   skill's `description:` field, warn on extreme length or
   forbidden patterns. continue/SKILL.md's 296-char description
   is acceptable today; this lint prevents future regression.

Neither is in scope for ADR-0047. They become natural Phase 10
boundary deliverables, or get filed as `.dev/debt.md` rows when
a future cycle has bandwidth.

### Verdict

**READY-TO-COMMIT.** No required fixes; the four edits land
as-is, this Status flips to Accepted, Revision history is
filled with the commit SHA on landing.

## References

- `/tmp/scaffolding-audit-2026-05-10.md` — full audit report
  (subagent output; not committed — `/tmp` is ephemeral)
- `.claude/skills/audit_scaffolding/CHECKS.md` — the §A〜§G
  framework the audit followed
- `.claude/rules/lessons_vs_adr.md` — ADR vs lesson decision
  tree (this ADR self-justifies its ADR shape per the same tree)
- ADR-0030 (`0030_x86_64_emit_test_split.md`) — referenced as
  the false-positive that the audit flagged

## Revision history

| Date       | Commit         | Note                                                                                                          |
|------------|----------------|---------------------------------------------------------------------------------------------------------------|
| 2026-05-10 | `(this commit)` | Accepted. Edits A-D landed; subagent self-review confirmed no load-bearing loss; SHA backfills at phase close. |
