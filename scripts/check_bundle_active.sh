#!/usr/bin/env bash
# check_bundle_active.sh — bundle-mode state machine validator.
#
# Per ADR-0118 D6 + .claude/skills/continue/SKILL.md §"Bundle mode".
# Codifies the atom-rhythm defense (lesson e62db476 + 2026-05-26).
#
# Modes:
#   bash scripts/check_bundle_active.sh             # validate schema; exit 0 if active+valid
#   bash scripts/check_bundle_active.sh --close     # validate exit-condition met before retire
#
# Exit codes:
#   0 — no Active bundle section, OR Active bundle present + schema valid
#   1 — schema invalid (missing required field)
#   2 — --close requested but exit-condition not yet demonstrably met
#   3 — handover.md not found

set -u

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
handover="$repo_root/.dev/handover.md"
mode="${1:-validate}"

if [[ ! -f "$handover" ]]; then
  echo "[check_bundle_active] handover.md not found: $handover"
  exit 3
fi

# Extract Active bundle section (lines from `## Active bundle` to next `## ` or EOF).
section="$(awk '/^## Active bundle/{flag=1; next} /^## /{flag=0} flag' "$handover")"

if [[ -z "$section" ]]; then
  if [[ "$mode" == "--close" ]]; then
    echo "[check_bundle_active] no Active bundle section — nothing to close"
    exit 0
  fi
  echo "[check_bundle_active] no Active bundle section (loop in normal mode)"
  exit 0
fi

# Required fields per ADR-0118 D6.
required=("Bundle-ID" "Cycles-remaining" "Continuity-memo" "Exit-condition")
missing=()
for field in "${required[@]}"; do
  if ! echo "$section" | grep -qE "\\*\\*${field}\\*\\*:|^\\s*-\\s+\\*\\*${field}\\*\\*:"; then
    missing+=("$field")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "[check_bundle_active] FAIL — schema invalid; missing fields:"
  for m in "${missing[@]}"; do echo "  - $m"; done
  echo ""
  echo "Bundle section template (per SKILL.md §\"Bundle mode\"):"
  echo "  ## Active bundle"
  echo ""
  echo "  - **Bundle-ID**: <range>"
  echo "  - **Cycles-remaining**: <N>"
  echo "  - **Continuity-memo**: <observables to watch>"
  echo "  - **Exit-condition**: <concrete measurable delta>"
  exit 1
fi

bundle_id="$(echo "$section" | grep -oE '\*\*Bundle-ID\*\*:[^\n]*' | head -1 | sed 's/.*Bundle-ID\*\*:\s*//')"
exit_cond="$(echo "$section" | grep -oE '\*\*Exit-condition\*\*:[^\n]*' | head -1 | sed 's/.*Exit-condition\*\*:\s*//')"

if [[ "$mode" == "--close" ]]; then
  # The --close mode prints the exit-condition for human verification.
  # We cannot mechanically verify arbitrary deltas (test counts / behaviour
  # observables), so we require the user/loop to confirm + cite evidence.
  echo "[check_bundle_active] BUNDLE-CLOSE-REQUEST: $bundle_id"
  echo "  Exit-condition: $exit_cond"
  echo ""
  echo "Before retiring the Active bundle section, confirm + cite:"
  echo "  - Has the exit-condition delta been observed in this cycle?"
  echo "    (test count moved / HandlerEntry registered / FAIL count moved / etc.)"
  echo "  - Cite the SHA where the observable delta landed."
  echo "  - If delta = 0, the bundle either extends N or pivots — not closes."
  echo ""
  echo "Loop should commit handover.md with the Active bundle section REMOVED"
  echo "and the delta-evidence in the commit body."
  exit 0
fi

# Default validate mode: schema OK.
echo "[check_bundle_active] OK — Active bundle '$bundle_id' schema valid"
echo "  Exit-condition: $exit_cond"
exit 0
