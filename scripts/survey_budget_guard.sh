#!/usr/bin/env bash
# Survey-budget guard — mechanical enforcement of the "fork Step-0
# surveys to an Explore subagent" discipline (textbook_survey.md;
# lesson 2026-05-31-continue-context-burn-survey-in-main).
#
# Wired as PreToolUse hooks on Read|Grep|Bash|Edit|Write|Task|Agent and a
# UserPromptSubmit hook. It counts MAIN-CONTEXT survey operations (Read /
# Grep / primary-verb-search Bash) per turn and:
#   - SOFT (advisory, stdout, non-blocking): "you're surveying in
#     main; consider forking to an Explore subagent".
#   - HARD (exit 2, blocks the tool, feeds the reason to the model):
#     forces a pause so the remaining survey gets forked.
# The counter RESETS to 0 on: a new user message (UserPromptSubmit), a
# subagent dispatch (Task / Agent — survey forked), or an Edit / Write
# (implementation mode — interleaved reads are legit lookups, not a survey).
# So the guard is self-healing: fork a subagent OR start implementing and
# it gets out of the way; only a LONG PURE survey (many reads, no writes,
# no subagent) trips the block.
#
# Why a hook and not just prose: the prose rule already existed and
# was not followed (the survey ran in main and burned ~83% of the
# 200K window in ~10 min). This makes the discipline mechanical.

set -euo pipefail

SOFT="${SURVEY_BUDGET_SOFT:-7}"
HARD="${SURVEY_BUDGET_HARD:-12}"

payload="$(cat)"

# Robust field extraction (python3 is already a hook dependency here).
read -r EVENT TOOL SESSION CMD <<EOF
$(python3 - "$payload" <<'PY'
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    print("? ? ? ?"); raise SystemExit
ev = d.get("hook_event_name", "?")
tool = d.get("tool_name", "?")
sess = d.get("session_id", "default")
cmd = (d.get("tool_input", {}) or {}).get("command", "")
cmd = " ".join(cmd.split()) if isinstance(cmd, str) else ""
import re
# A Bash call counts as "survey" ONLY if its PRIMARY verb is a read-only
# search (grep/rg/ag/find). This avoids false positives on build/test/git
# commands that merely pipe through tail/cat/head to inspect a log
# (e.g. `zig build 2>log; tail log`). Strip cd/env/timeout prefixes first;
# build/test/git/ssh verbs never count.
s = re.sub(r'^(cd\s+\S+\s*&&\s*)+', '', cmd)
s = re.sub(r'^(timeout\s+\d+\s+)', '', s)
s = re.sub(r'^([A-Za-z_][A-Za-z0-9_]*=\S+\s+)+', '', s)
first = (s.split() or [""])[0].split("/")[-1]
is_build = bool(re.match(r'^(zig|git|cargo|make|npm|bash|sh|nix|ssh|gh|rm|mkdir|cp|mv|echo|ls|chmod|wc|python3?)$', first))
survey = (not is_build) and bool(re.match(r'^(grep|rg|ag|find)$', first))
print(ev, tool, sess, "SURVEYCMD" if survey else "OTHERCMD")
PY
)
EOF

state_dir="${CLAUDE_PROJECT_DIR:-.}/private"
mkdir -p "$state_dir" 2>/dev/null || true
state_file="$state_dir/.survey_budget_${SESSION}"

# Reset signals: new user turn, or a subagent dispatch (survey forked).
case "$EVENT" in
  UserPromptSubmit) echo 0 > "$state_file" 2>/dev/null || true; exit 0 ;;
esac
# Task/Agent = survey forked to a subagent → reset. Edit/Write = entering
# implementation mode (reads here are legit lookups, not a survey) → reset.
case "$TOOL" in
  Task|Agent|Edit|Write|MultiEdit|NotebookEdit) echo 0 > "$state_file" 2>/dev/null || true; exit 0 ;;
esac

# Count only main-context survey operations.
is_survey=0
case "$TOOL" in
  Read|Grep) is_survey=1 ;;
  Bash) [ "$CMD" = "SURVEYCMD" ] && is_survey=1 ;;
esac
[ "$is_survey" -eq 1 ] || exit 0

count=0
[ -f "$state_file" ] && count="$(cat "$state_file" 2>/dev/null || echo 0)"
count=$((count + 1))
echo "$count" > "$state_file" 2>/dev/null || true

if [ "$count" -ge "$HARD" ]; then
  # exit 2 → tool blocked, stderr fed back to the model as the reason.
  echo "🛑 Survey-budget guard: ${count} main-context survey ops this turn (Read/Grep/grep-Bash) without forking. Per textbook_survey.md + lesson 2026-05-31-continue-context-burn-survey-in-main, Step-0 surveys MUST be forked to an Explore subagent (Agent tool, subagent_type 'Explore'). Dispatch a subagent for the remaining file reads — that resets this budget. (Override: SURVEY_BUDGET_HARD env.)" >&2
  exit 2
fi

if [ "$count" -ge "$SOFT" ]; then
  echo "[survey-budget] ${count} main-context survey ops this turn — consider forking the rest to an Explore subagent (textbook_survey.md). Hard stop at ${HARD}."
fi

exit 0
