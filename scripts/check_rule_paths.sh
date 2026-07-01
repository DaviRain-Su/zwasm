#!/usr/bin/env bash
# scripts/check_rule_paths.sh — lint .claude/rules/*.md for frontmatter/body
# alignment drift.
#
# Per D-058 (filed during ADR-0048 Phase 5 audit; the discharge trigger was
# "Phase 10 boundary audit_scaffolding" — cycle 82 ran that audit, so this
# script is the discharge artifact).
#
# Each .claude/rules/<x>.md file declares:
# 1. Frontmatter `paths:` list — which files trigger auto-load.
# 2. Body "Auto-loaded when editing X" sentence — human-readable scope.
#
# Drift symptom: frontmatter says "src/**/*.zig" but body says "editing Zig
# sources, ADRs, and rules" (omits the ADRs / rules — body is broader than
# frontmatter, suggesting the rule should auto-load more widely than it does).
# Reverse drift: body says "Zig sources only" but frontmatter includes
# .dev/ROADMAP.md (rule fires on more than the body promises). The former
# misses load triggers; the latter creates surprise loads.
#
# This script flags both directions as `warn` findings. Reviewer judges
# whether to widen frontmatter, narrow body prose, or accept the asymmetry
# (the body sometimes lists doc-only files for human reference where the
# frontmatter is code-focused — that's fine).
#
# Output format: `[check_rule_paths] <severity> <file>:<line>: <message>`.
# Exit code 0 unless --gate; --gate exits 1 on any `warn`.

set -u
cd "$(dirname "$0")/.."

GATE=0
if [ "${1:-}" = "--gate" ]; then GATE=1; fi

findings=0

# Extract the body's "Auto-loaded when editing ..." sentence (often within
# the first 10 lines after frontmatter). Returns "" if not present.
extract_auto_load_sentence() {
  local f="$1"
  # Skip frontmatter (between two `---` lines), then grep first occurrence.
  awk '
    /^---$/{c++; if (c == 2) { in_body = 1; next }}
    in_body && /[Aa]uto-loaded when/ { print; exit }
  ' "$f"
}

# Extract `paths:` list from frontmatter. Note: gsub modifies $0, so we
# copy to a local var before stripping the leading "  - " + quotes —
# otherwise the "exit paths mode" rule below fires on the same line.
extract_paths() {
  local f="$1"
  awk '
    /^---$/{c++; if (c == 2) exit; next}
    c == 1 && /^paths:/ { in_paths = 1; next }
    c == 1 && in_paths && /^  - / {
      line = $0
      sub(/^  - "?/, "", line); sub(/"$/, "", line)
      print line
      next
    }
    c == 1 && in_paths && !/^$/ { in_paths = 0 }
  ' "$f"
}

for f in .claude/rules/*.md; do
  name=$(basename "$f")
  # Skip files that don't have frontmatter at all (some sibling docs).
  if ! head -1 "$f" | grep -qE '^---$'; then continue; fi

  paths=$(extract_paths "$f")
  auto_sentence=$(extract_auto_load_sentence "$f")

  # Drift 1: body has auto-load sentence but no frontmatter paths.
  # (Inverse — missing sentence in body is stylistic, not a bug.)
  if [ -z "$paths" ] && [ -n "$auto_sentence" ]; then
    echo "[check_rule_paths] warn $f: body declares 'Auto-loaded when editing' but frontmatter has no paths: (rule won't actually auto-load)"
    findings=$((findings + 1))
    continue
  fi

  # Drift 2: body sentence mentions a file class that frontmatter doesn't.
  # Class names map directly to path-glob substrings (avoid display-name
  # synonyms like "ADR" → "decisions" which trigger false positives).
  if [ -n "$auto_sentence" ] && [ -n "$paths" ]; then
    paths_joined=$(echo "$paths" | tr '\n' ' ')
    sentence_lower=$(echo "$auto_sentence" | tr '[:upper:]' '[:lower:]')
    paths_lower=$(echo "$paths_joined" | tr '[:upper:]' '[:lower:]')
    # Each pair: <body keyword to grep for> <expected substring in paths>.
    # If body mentions the first, paths must contain the second.
    drift_pairs=(
      "roadmap roadmap"
      "handover handover"
      ".dev/debt debt"
      "decisions decisions"
      "lessons lessons"
      "scripts/ scripts"
      "build.zig build.zig"
      "include/ include"
    )
    for pair in "${drift_pairs[@]}"; do
      body_kw="${pair% *}"
      path_kw="${pair#* }"
      if echo "$sentence_lower" | grep -qF "$body_kw"; then
        if ! echo "$paths_lower" | grep -qF "$path_kw"; then
          echo "[check_rule_paths] warn $f: body mentions '$body_kw' but frontmatter paths: does not include any '$path_kw' glob"
          findings=$((findings + 1))
        fi
      fi
    done
  fi
done

echo
if [ "$findings" -eq 0 ]; then
  echo "[check_rule_paths] OK — $(ls .claude/rules/*.md | wc -l | tr -d ' ') rules checked, 0 drift findings"
else
  echo "[check_rule_paths] $findings drift finding(s) — investigate per file_size_smell.md decision tree (widen paths: OR narrow body sentence)"
fi

if [ "$GATE" -eq 1 ] && [ "$findings" -gt 0 ]; then exit 1; fi
exit 0
