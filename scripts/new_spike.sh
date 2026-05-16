#!/usr/bin/env bash
# Scaffold a new spike under `private/spikes/<slug>/`. Per
# `.claude/rules/extended_challenge.md` Step 4, spikes are
# autonomous-in-scope ≤ 1-day throwaway experiments whose outcome
# MUST land as ADR / lesson / production fix / rejected-rationale —
# never as a silent gitignored artifact.
#
# This script:
#   1. Creates `private/spikes/<slug>/` (gitignored under `private/`).
#   2. Drops a README.md with a `Status` line forcing one of:
#      starting / running / promoted-to-adr / promoted-to-lesson /
#      merged-into-prod / rejected.
#   3. Drops `notes.md` for raw observations.
#
# Pairs with `scripts/audit_spikes.sh` (separate) which scans
# orphaned spikes (Status: running > 14 days, or no Outcome line
# after 30 days) for promotion / cleanup.
#
# Usage:
#   bash scripts/new_spike.sh <slug>
#   bash scripts/new_spike.sh d134-altstack-investigation

set -uo pipefail

cd "$(dirname "$0")/.."

if [ $# -ne 1 ]; then
  echo "usage: $0 <slug>" >&2
  echo "  slug: short-kebab-case identifier (e.g. d134-segv-investigation)" >&2
  exit 2
fi

slug="$1"
case "$slug" in
  *[!a-zA-Z0-9_-]*) echo "ERROR: slug must be [a-zA-Z0-9_-]+; got: $slug" >&2; exit 2 ;;
esac

dir="private/spikes/$slug"
if [ -e "$dir" ]; then
  echo "ERROR: $dir already exists. Pick a different slug or delete it." >&2
  exit 2
fi

mkdir -p "$dir"
date_iso=$(date -u +%Y-%m-%d)
sha=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")

cat > "$dir/README.md" <<EOF
# Spike: $slug

**Created**: $date_iso (@ $sha)
**Status**: running
**Outcome**: <TBD — must resolve before this directory exits gitignore>

> Per \`.claude/rules/extended_challenge.md\` Step 4: a spike is a
> throwaway experiment, ≤ 1 day of work. Outcome lands as one of:
> ADR (rejected → ADR Status: Rejected; merged → no ADR but cite
> production commit), lesson (observational), or deletion (no
> learning worth keeping).

## Hypothesis

<What are we testing? State as a falsifiable claim.>

## Setup

<Commands to reproduce the spike environment. What dependencies,
what binary, what flags.>

## Results

<Raw measurements / outputs. Reference \`notes.md\` for free-form
log.>

## Decision

<After ≤ 1 day: pick one>

- [ ] **Promoted to ADR**: filed \`.dev/decisions/NNNN_<slug>.md\` —
  cite ADR path here. Update **Status** to \`promoted-to-adr\`.
- [ ] **Promoted to lesson**: filed
  \`.dev/lessons/$date_iso-<slug>.md\` — cite path here. Update
  **Status** to \`promoted-to-lesson\`.
- [ ] **Merged into production**: cite the production commit SHA.
  Update **Status** to \`merged-into-prod\`. Delete this directory.
- [ ] **Rejected (no learning)**: state why in one line. Update
  **Status** to \`rejected\`. Delete this directory.

## Audit hooks

\`scripts/audit_spikes.sh\` flags this spike if:
- **Status** stays \`running\` > 14 days since **Created**.
- **Outcome** stays \`<TBD>\` > 30 days since **Created**.
- The directory still exists with **Status** ∈ \`{merged-into-prod,
  rejected}\` (should have been deleted).
EOF

cat > "$dir/notes.md" <<EOF
# Spike notes: $slug

Raw observations, command outputs, hypotheses-in-progress. Trim
into README.md \`Results\` when the spike resolves.

---

EOF

echo "Created spike scaffold at $dir/"
echo ""
echo "Next:"
echo "  1. Edit $dir/README.md Hypothesis + Setup sections."
echo "  2. Run experiments; append to $dir/notes.md."
echo "  3. Resolve within ≤ 1 day per extended_challenge.md Step 4."
echo "  4. Update README.md Status + Outcome at close."
