---
paths:
  - ".dev/*.md"
  - ".dev/archive/**/*.md"
---

# Doc-state marker convention

Auto-loaded when editing `.dev/` markdown. Codifies the 4-state
vocabulary that the 2026-05-22 audit (Agent 3) found necessary
after 4 close-plan docs accumulated without clear lifecycle
markers, producing claim drift between docs.

## The rule

Every `.dev/*.md` file (except `ROADMAP.md` / `handover.md` /
`debt.md` / `proposal_watch.md` / `lessons/INDEX.md` — those are
always-active) MUST declare its `Doc-state:` in a top-of-file
blockquote within the first 5 lines.

```markdown
# Phase X close plan

> **Doc-state**: ACTIVE — load-bearing for current Phase X work.

(body...)
```

## The 4 states

| State | Meaning |
|---|---|
| `ACTIVE` | Load-bearing for current Phase / cycle work. Other docs / rules / ADRs cite this; editing requires §18 procedure when text is normative |
| `ARCHIVED-IN-PLACE` | Closed at this path. Kept here because outbound refs (ADRs / rules / ROADMAP) cite this path. Don't edit. Optionally add `> **Superseded-by**: <path>` |
| `ARCHIVED` | Moved from `<old-path>` to `.dev/archive/<subdir>/` or similar. The original path no longer exists; this Doc-state line should also include `> **Genesis**: <YYYY-MM-DD authoring rationale>` |
| `SUPERSEDED-BY` | Content rolled into `<ref>`; file kept as breadcrumb. Body should be 1-3 lines pointing at the successor |

## Why this rule exists

The 2026-05-22 audit found 4 close-plan docs (`phase9_close_plan.md`,
`phase9_completion_master_plan.md`, `phase9_13_0_close_plan.md`,
`phase9_structural_debt_close_plan.md`) coexisting with overlapping
scope, each pre-dating the others, each cited from different
ADRs / rules / SKILL.md. Without explicit lifecycle markers, future
sessions couldn't tell which was authoritative — leading to the
"premature §9.13-0 [x] flip" drift the audit surfaced.

The marker discipline is **structural**: the audit script greps for
missing markers and surfaces them as `block` findings before
Phase-close.

## Reviewer checklist

- [ ] Does the new `.dev/` doc declare a `Doc-state:`?
- [ ] If archiving, does the new path under `.dev/archive/` add
      a `Doc-state: ARCHIVED 2026-MM-DD — superseded by <path>`
      line?
- [ ] If a doc transitions ACTIVE → ARCHIVED, are all outbound
      citations (grep for the doc filename in ROADMAP / debt /
      ADRs / `.claude/`) updated or explicitly accepted as
      lineage-only?

## What does NOT need a marker

- `ROADMAP.md` (always ACTIVE; it's the rulebook).
- `handover.md` (always ACTIVE; replaced each cycle).
- `debt.md` (always ACTIVE; appended each cycle).
- `proposal_watch.md` (always ACTIVE; periodic-review log).
- `.dev/lessons/INDEX.md` (always ACTIVE; lessons themselves
  may carry markers if archived).
- `.dev/decisions/*.md` — ADRs have their own `Status:`
  lifecycle that subsumes this marker.

## Audit hook (Phase 10+ work)

`audit_scaffolding` skill should grep `.dev/*.md` (excluding
the exempt list above) for missing `Doc-state:` and surface as
`block` findings. Until that hook lands, manual review at
Phase-close pre-flight.

## Related

- `.dev/phase9_close_master.md` §4 — the doc-state vocabulary
  was introduced by this rule's parent audit (2026-05-22
  Agent 3 finding).
- `.claude/rules/lessons_vs_adr.md` — the ADR lifecycle
  vocabulary (`Status:`) this rule complements but does not
  replace.
- `.claude/rules/spike_lifecycle.md` — spike-directory
  Status discipline; same shape applies to `private/spikes/`.
