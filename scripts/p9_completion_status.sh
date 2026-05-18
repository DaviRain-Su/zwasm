#!/usr/bin/env bash
# scripts/p9_completion_status.sh — Phase 9 completion live progress
# (skeleton).
#
# Live status for §9.12-A..I sub-row progression. Companion to the §9.9
# era `scripts/p9_simd_status.sh`. Reads `.dev/p9_completion_progress.yaml`
# and reconciles it against current source state (per-op file count,
# skip-impl counters from spec_assert runners, enforcement-9-item wiring,
# debt `now` rows). Output is authoritative; handover narrative quotes it
# without prediction (per `.claude/rules/no_handover_predictions.md`).
#
# Phase 9 completion master plan §7.8.
#
# Status: skeleton (2026-05-19) — completed in §9.12-A. Currently emits a
# one-paragraph summary by reading the yaml + a small set of source greps.

set -uo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,16p' "$0"
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
YAML="$ROOT/.dev/p9_completion_progress.yaml"
HIST="$ROOT/bench/results/skip_impl_history.yaml"

echo "=== Phase 9 completion — progress status (skeleton) ==="
echo ""

if [ -f "$YAML" ]; then
  echo "--- progress yaml (.dev/p9_completion_progress.yaml) ---"
  head -40 "$YAML"
else
  echo "[warn] $YAML not found — seed at §9.12-A landing"
fi

echo ""
if [ -f "$HIST" ]; then
  echo "--- skip-impl history (latest 5 rows) ---"
  tail -25 "$HIST"
else
  echo "[warn] $HIST not found — seed at §9.12-A landing"
fi

echo ""
echo "=== currently 'now' debt rows ==="
grep -hE '^\| D-[0-9]+ +\| [a-z ]+ +\| now ' "$ROOT/.dev/debt.md" 2>/dev/null \
  | awk -F'|' '{ id=$2; gsub(/ /, "", id); body=$5; gsub(/^[[:space:]]+|[[:space:]]+$/, "", body); print id ": " substr(body, 1, 100) }' \
  | head -10

echo ""
echo "=== live spec_assert counts (cached if recent) ==="
if [ -f "/tmp/non-simd-full.log" ]; then
  grep -E "^spec_assert_runner_non_simd:" /tmp/non-simd-full.log | tail -1
fi
if [ -f "/tmp/p9-mac-simd.log" ]; then
  grep -E "^simd_assert_runner:" /tmp/p9-mac-simd.log | tail -1
fi

echo ""
echo "[p9_completion_status] skeleton — full machine-readable output in §9.12-A"
exit 0
