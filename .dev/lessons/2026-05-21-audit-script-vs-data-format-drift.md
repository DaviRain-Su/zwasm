# Audit-script vs data format drift — synthetic smoke-test discipline

**Date**: 2026-05-21
**Keywords**: audit_spikes, p9_completion_status, check_skip_taxonomy_pairing, format drift, awk, regex, debt.md, spike README, markdown table, false-negative
**Citing**: `33af8d5a` (audit_spikes format-relax) + `37bd8101` (p9_completion_status now-row detector) + `2e8f0f22` (check_skip_taxonomy_pairing — discharge-SHA inline resolution)

## What happened

Three audit scripts that read project artefacts silently mis-fired
because the scripts' regex shape did not match the actual data
format on disk:

- `audit_spikes.sh` looked for `^**Status**:` / `^**Created**:` —
  q3-* spike READMEs used `- **Status**:` (bullet form) + `- **Date**:`
  (synonym). All 3 q3 spikes surfaced as "missing Status or Created
  header" findings even though the fields were present.
- `p9_completion_status.sh` debt-sweep awk matched `^### D-NNN`
  headings + `^- Status: now` bullets — debt.md actually uses
  markdown-table form (`| D-NNN | layer | status | ...`). The
  detector returned 0 unconditionally regardless of actual `now`
  rows.
- `check_skip_taxonomy_pairing.sh` flagged discharged-D-NNN
  citations as drift even after the ADR-0078 paired-artifact column
  was updated inline with the discharge SHA; needed a backtick-aware
  "discharge SHA in artifact text" check.

## Root cause

When a project rule documents an artefact format (e.g.
`spike_lifecycle.md` template specifies `**Started**:`), the
**actually-emitted** format may drift from that template over time
as scaffolds (`new_spike.sh` emits `Created`), legacy authors (q3
spikes used `Date`), and edge cases (backticks around inline
values) introduce variants. Audit scripts written to the rule's
canonical form silently miss the variants. The signature is
"audit always reports 0 findings even when data is messy" — a
**false-negative** mode that's hard to notice by eyeballing the
report.

## Fix (or path forward)

Make audit-script regexes **format-tolerant**: accept the canonical
form + any historical variant in-tree. Three concrete tactics:

1. **Bullet prefix tolerance**: `^-?\s*\*\*Field\*\*:` matches both
   bullet-list (`- **Field**:`) and top-level (`**Field**:`) forms.
2. **Synonym accept-list**: alternation over field-name variants
   (`(Created|Started|Date)`).
3. **Inline-formatting strip**: `tr -d '\`'` removes inline-code
   backticks around values before case-matching the canonical
   keyword (e.g. `Status: \`merged-into-prod\``).

For new audit scripts: add a **synthetic smoke-test** at write
time — feed the awk a hand-crafted fixture exercising each
variant; assert the count matches expectation. Catches the
false-negative class before the script ships.

## Why this didn't surface earlier

Audit scripts default to soft-mode (report-only); a script that
always emits 0 findings looks like "everything's clean" rather
than "the detector is broken". Only `--gate` (pre-push) mode
exercises the failure axis hard enough to surface format
mismatches — and even then, only when a real violation exists
to be flagged.

The §9.12-A enforcement layer landed several gates within days
(7.1–7.9); the same format-drift class hit all three audit
scripts within the same window. The pattern is structural to
"audit script + tracked artefact" coupling, not an isolated bug.

## Related

- `.claude/rules/spike_lifecycle.md` — declares `**Started**:` as
  template canonical; audit now accepts that + `Created`/`Date`.
- `.claude/skills/audit_scaffolding/CHECKS.md §F` — debt-coherence
  check shape (script-vs-data alignment expectations).
- `.dev/lessons/2026-05-16-narrative-claim-vs-landed-state.md` —
  sibling class: "narrative claims diverge from landed state".
  The synthetic-smoke-test discipline above generalises the same
  spirit to audit scripts themselves.
