#!/usr/bin/env bash
# scripts/check_skill_descriptions.sh — lint .claude/skills/*/SKILL.md
# frontmatter `description:` fields for quality.
#
# Per D-059 (filed during ADR-0048 Phase 5 audit; the discharge trigger was
# "Phase 10 boundary audit_scaffolding" — cycle 82 ran that audit, so this
# script is the discharge artifact).
#
# Three checks per skill description:
#
# 1. **Length** — Claude Code's skill-trigger LLM benefits from descriptions
#    in roughly 80-700 characters. Too short → trigger ambiguous; too long
#    → noisy / less likely to fire on the right keywords. Outside this band
#    is a `warn` finding.
#
# 2. **Forbidden vague triggers** — phrases like "consider when", "you might",
#    "maybe useful" are weak triggers that hurt selection accuracy. Skills
#    should declare concrete triggers ("Trigger when the user says X").
#
# 3. **Trigger-keyword presence** — for each skill, declare 1+ explicit trigger
#    keyword (Japanese / English / slash-command). If the description has no
#    "Trigger" / "Invoke" / "Fires" / "Use when" anchor, the skill is unlikely
#    to be auto-selected when relevant.
#
# Output format: `[check_skill_descriptions] <severity> <skill>: <message>`.
# Exit code 0 unless --gate; --gate exits 1 on any `warn`.

set -u
cd "$(dirname "$0")/.."

GATE=0
if [ "${1:-}" = "--gate" ]; then GATE=1; fi

MIN_LEN=80
MAX_LEN=800

findings=0

# Extract description field value (single-line or first line of multi-line).
extract_description() {
  local f="$1"
  awk '
    /^---$/{c++; if (c == 2) exit}
    c == 1 && /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      print
      exit
    }
  ' "$f"
}

for f in .claude/skills/*/SKILL.md; do
  name=$(basename "$(dirname "$f")")
  desc=$(extract_description "$f")

  if [ -z "$desc" ]; then
    echo "[check_skill_descriptions] warn $name: SKILL.md frontmatter has no description: field"
    findings=$((findings + 1))
    continue
  fi

  # 1. Length check
  len=${#desc}
  if [ "$len" -lt "$MIN_LEN" ]; then
    echo "[check_skill_descriptions] warn $name: description is $len chars (< $MIN_LEN); trigger keywords may be ambiguous"
    findings=$((findings + 1))
  elif [ "$len" -gt "$MAX_LEN" ]; then
    echo "[check_skill_descriptions] warn $name: description is $len chars (> $MAX_LEN); consider trimming to the trigger essence"
    findings=$((findings + 1))
  fi

  # 2. Forbidden vague triggers
  desc_lower=$(echo "$desc" | tr '[:upper:]' '[:lower:]')
  for vague in "consider when" "you might" "maybe useful" "could be helpful"; do
    if echo "$desc_lower" | grep -qF "$vague"; then
      echo "[check_skill_descriptions] warn $name: description contains vague trigger phrase '$vague' — replace with concrete trigger"
      findings=$((findings + 1))
    fi
  done

  # 3. Trigger-keyword anchor (look for one of several common anchors)
  has_anchor=0
  for anchor in "Trigger" "Invoke" "Fires" "Use when" "Run when" "When" "起動" "発火"; do
    if echo "$desc" | grep -qF "$anchor"; then
      has_anchor=1
      break
    fi
  done
  if [ "$has_anchor" -eq 0 ]; then
    echo "[check_skill_descriptions] warn $name: description has no trigger anchor (Trigger / Invoke / Fires / Use when / When / 起動 / 発火); auto-selection may misfire"
    findings=$((findings + 1))
  fi
done

skill_count=$(ls .claude/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
echo
if [ "$findings" -eq 0 ]; then
  echo "[check_skill_descriptions] OK — $skill_count skill(s) checked, 0 description findings"
else
  echo "[check_skill_descriptions] $findings finding(s) across $skill_count skill(s)"
fi

if [ "$GATE" -eq 1 ] && [ "$findings" -gt 0 ]; then exit 1; fi
exit 0
