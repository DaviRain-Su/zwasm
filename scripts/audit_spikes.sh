#!/usr/bin/env bash
# Audit `private/spikes/*/README.md` for orphaned / stale spikes.
# Per `.claude/rules/extended_challenge.md` Step 4 + new_spike.sh
# scaffold, every spike directory must:
#   - Be created with `scripts/new_spike.sh` (so README has the
#     Status / Outcome / Created fields).
#   - Resolve within ≤ 1 day of work; Status moves off `running`.
#   - Be DELETED once Status ∈ {merged-into-prod, rejected}.
#
# This script surfaces violations:
#   - Status: running and Created > 14 days ago.
#   - Outcome: <TBD> and Created > 30 days ago.
#   - Directory exists with Status ∈ {merged-into-prod, rejected}.
#   - Spike directory without README.md (uncategorised).
#
# Usage:
#   bash scripts/audit_spikes.sh          # warn only (exit 0)
#   bash scripts/audit_spikes.sh --strict # exit 1 if any finding

set -uo pipefail

cd "$(dirname "$0")/.."

strict=0
case "${1:-}" in
  --strict) strict=1 ;;
  "") ;;
  *) echo "usage: $0 [--strict]" >&2; exit 2 ;;
esac

now_epoch=$(date -u +%s)

age_days() {
  # $1 = ISO date YYYY-MM-DD; emit age in days
  # macOS date and GNU date differ; try both.
  local d="$1"
  local then_epoch
  then_epoch=$(date -j -f "%Y-%m-%d" "$d" "+%s" 2>/dev/null \
    || date -d "$d" "+%s" 2>/dev/null \
    || echo 0)
  if [ "$then_epoch" -eq 0 ]; then
    echo "?"; return
  fi
  echo $(( (now_epoch - then_epoch) / 86400 ))
}

count=0
spikes_dir="private/spikes"
if [ ! -d "$spikes_dir" ]; then
  echo "no private/spikes/ directory; nothing to audit"
  exit 0
fi

for d in "$spikes_dir"/*/; do
  [ -d "$d" ] || continue
  slug=$(basename "$d")
  readme="$d/README.md"
  if [ ! -f "$readme" ]; then
    echo "WARN  $slug: no README.md (use scripts/new_spike.sh going forward)"
    count=$((count + 1))
    continue
  fi

  # Accept both `**Field**:` (canonical) and `- **Field**:` (bullet-list
  # form used by older spikes pre-`new_spike.sh`). Accept any of
  # `Created` / `Started` / `Date` for the creation-date field — the
  # spike_lifecycle.md template names `Started`; `new_spike.sh` emits
  # `Created`; the early q3-* spikes use `Date`. All three carry the
  # same semantic (ISO YYYY-MM-DD).
  # `tr -d` strips inline-code backticks (e.g. `Status: \`merged-into-prod\` (note)`).
  status=$(grep -E '^-?\s*\*\*Status\*\*:' "$readme" | head -1 | sed -E 's/^-?\s*\*\*Status\*\*:\s*//' | tr -d '`' | awk '{print $1}')
  outcome=$(grep -E '^-?\s*\*\*Outcome\*\*:' "$readme" | head -1 | sed -E 's/^-?\s*\*\*Outcome\*\*:\s*//')
  created=$(grep -E '^-?\s*\*\*(Created|Started|Date)\*\*:' "$readme" | head -1 | sed -E 's/^-?\s*\*\*(Created|Started|Date)\*\*:\s*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\2/')

  if [ -z "$status" ] || [ -z "$created" ]; then
    echo "WARN  $slug: README.md missing Status or Created/Started/Date header"
    count=$((count + 1))
    continue
  fi

  age=$(age_days "$created")

  case "$status" in
    running)
      if [ "$age" != "?" ] && [ "$age" -gt 14 ]; then
        echo "WARN  $slug: Status=running for $age days (> 14d); resolve or convert to ADR/lesson"
        count=$((count + 1))
      fi
      if echo "$outcome" | grep -qE '<TBD' && [ "$age" != "?" ] && [ "$age" -gt 30 ]; then
        echo "WARN  $slug: Outcome=<TBD> for $age days (> 30d); spike has likely been abandoned"
        count=$((count + 1))
      fi
      ;;
    merged-into-prod|rejected)
      echo "WARN  $slug: Status=$status but directory still exists; delete this spike"
      count=$((count + 1))
      ;;
    promoted-to-adr|promoted-to-lesson)
      # Keep the directory as historical reference; OK.
      :
      ;;
    starting)
      if [ "$age" != "?" ] && [ "$age" -gt 7 ]; then
        echo "WARN  $slug: Status=starting for $age days (> 7d); did the spike start?"
        count=$((count + 1))
      fi
      ;;
    *)
      echo "WARN  $slug: Status=$status (unrecognised; expected one of running/starting/promoted-to-adr/promoted-to-lesson/merged-into-prod/rejected)"
      count=$((count + 1))
      ;;
  esac
done

if [ "$count" -eq 0 ]; then
  echo "OK: all spikes within lifecycle bounds"
  exit 0
fi

echo ""
echo "$count spike audit finding(s). Per .claude/rules/extended_challenge.md Step 4, each spike must resolve to ADR / lesson / production / rejection."

if [ "$strict" -eq 1 ]; then
  exit 1
fi
exit 0
