#!/usr/bin/env bash
# scripts/check_skip_impl_ratchet.sh — Skip-impl one-way ratchet gate.
#
# Compares the current commit's gated skip-count against the previous entry
# in `bench/results/skip_impl_history.yaml`. FAILs if the count strictly
# increased AND the current commit's diff does not introduce a new yaml
# row whose `exempt:` field cites an ADR.
#
# Per-class semantics (ADR-0078; D-155 part 1):
#   gated_total = manifest_total + runtime_debt_trackable + runtime_adr_required
# `runtime_internal` counts are reported but never gate.
#
# Manifest counts come from runner summary lines:
#   "<runner>: ... (= N skip-impl + M runtime-skip + K skip-adr) ..."
# Runtime SKIP-<TOKEN> emissions are grep'd from the per-fixture log lines
# and classified via the canonical table in
#   .dev/decisions/0078_spec_runner_skip_token_taxonomy.md
#
# Modes:
#   --gate    : exit non-zero on regression without exempt (pre-push hook)
#   --measure : run live spec_assert runners and emit a new yaml row
#               candidate (author commits if intentional)
#   --report  : exit 0; show current vs prev with delta
#   (none)    : same as --report
#
# Live measurement is expensive. The script prefers cached logs at
# /tmp/non-simd-full.log + /tmp/p9-mac-simd.log when fresh (< 1 h).

set -uo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,30p' "$0"
  exit 0
fi

MODE="${1:-report}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

YAML="$ROOT/bench/results/skip_impl_history.yaml"
ADR="$ROOT/.dev/decisions/0078_spec_runner_skip_token_taxonomy.md"

# --- ADR-0078 taxonomy ---------------------------------------------------

# Emit one "TOKEN<TAB>CLASS" line per row in ADR-0078's canonical table.
# Table rows look like:
#   | `SKIP-CROSS-MODULE-IMPORTS`    | `debt-trackable`  | D-153 ...
load_taxonomy() {
  [ -f "$ADR" ] || return 1
  awk -F'|' '
    /^\|[[:space:]]*`SKIP-/ {
      tok=$2; cls=$3
      gsub(/[`[:space:]]/, "", tok)
      gsub(/[`[:space:]]/, "", cls)
      if (tok ~ /^SKIP-/ && (cls == "debt-trackable" || cls == "ADR-required" || cls == "runner-internal"))
        printf "%s\t%s\n", tok, cls
    }
  ' "$ADR"
}

TAXONOMY="$(load_taxonomy)"
if [ -z "$TAXONOMY" ]; then
  echo "[check_skip_impl_ratchet] WARN — ADR-0078 taxonomy table not parseable; runtime classification skipped"
fi

# --- log freshness + measurement -----------------------------------------

NS_LOG="/tmp/non-simd-full.log"
SI_LOG="/tmp/p9-mac-simd.log"

log_fresh() {
  local f="$1"
  [ -f "$f" ] || return 1
  local mtime now age
  now=$(date +%s)
  mtime=$(date -r "$f" +%s 2>/dev/null || echo 0)
  case "$mtime" in
    *[!0-9]*|"") mtime=0 ;;
  esac
  age=$((now - mtime))
  [ "$age" -lt 3600 ]
}

if [ "$MODE" = "--measure" ] || ! log_fresh "$NS_LOG" || ! log_fresh "$SI_LOG"; then
  echo "[check_skip_impl_ratchet] live measurement (cached logs absent / stale)..."
  zig build test-spec-wasm-2.0-assert > "$NS_LOG" 2>&1 || true
  zig build test-spec-simd > "$SI_LOG" 2>&1 || true
fi

# --- current measurement: manifest counts --------------------------------

# Extract manifest skip-impl from runner summary line. The canonical format is:
#   "<runner>: N passed, M failed, K skipped (= <impl> skip-impl + ...) (over ...)"
extract_skip_impl() {
  local log="$1"
  [ -f "$log" ] || { echo 0; return; }
  local v
  v=$(grep -oE '\(=[[:space:]]*[0-9]+[[:space:]]+skip-impl' "$log" 2>/dev/null \
      | head -1 | grep -oE '[0-9]+' | head -1)
  if [ -z "$v" ]; then
    v=$(grep -oE 'skip-impl[[:space:]:]+[0-9]+' "$log" 2>/dev/null \
        | head -1 | grep -oE '[0-9]+' | head -1)
  fi
  echo "${v:-0}"
}

ns_manifest=$(extract_skip_impl "$NS_LOG")
si_manifest=$(extract_skip_impl "$SI_LOG")
manifest_total=$((ns_manifest + si_manifest))

# --- current measurement: per-class runtime SKIP-* counts ----------------

# Greps both logs for SKIP-<TOKEN> emissions and counts per ADR-0078 class.
# Output: three integers (debt-trackable, ADR-required, runner-internal).
classify_runtime_skips() {
  if [ -z "$TAXONOMY" ]; then
    echo "0 0 0"
    return
  fi
  local tmp
  tmp=$(mktemp -t skipratchet.XXXXXX)
  { grep -hoE 'SKIP-[A-Za-z0-9_-]+' "$NS_LOG" 2>/dev/null
    grep -hoE 'SKIP-[A-Za-z0-9_-]+' "$SI_LOG" 2>/dev/null; } > "$tmp"

  awk -v taxonomy="$TAXONOMY" '
    BEGIN {
      n = split(taxonomy, lines, "\n")
      for (i = 1; i <= n; i++) {
        split(lines[i], pair, "\t")
        if (pair[1] != "") cls[pair[1]] = pair[2]
      }
    }
    {
      tok = $0
      c = (tok in cls) ? cls[tok] : "UNKNOWN"
      counts[c]++
      if (c == "UNKNOWN") unknowns[tok]++
    }
    END {
      printf "%d %d %d", counts["debt-trackable"]+0, counts["ADR-required"]+0, counts["runner-internal"]+0
      if (length(unknowns) > 0) {
        printf "\n"
        for (t in unknowns) printf "UNKNOWN-TOKEN %s %d\n", t, unknowns[t]
      }
    }
  ' "$tmp"
  rm -f "$tmp"
}

classify_out=$(classify_runtime_skips)
# First line is the count triple; subsequent UNKNOWN-TOKEN lines are warnings.
read -r cur_debt cur_adr_req cur_internal < <(printf '%s' "$classify_out" | head -1)
cur_debt=${cur_debt:-0}; cur_adr_req=${cur_adr_req:-0}; cur_internal=${cur_internal:-0}
unknown_lines=$(printf '%s' "$classify_out" | awk 'NR>1')

cur_gated=$((manifest_total + cur_debt + cur_adr_req))

# --- previous baseline ---------------------------------------------------

# Pull the last entry's per-class fields. Missing fields default to 0
# (backward compat for pre-D-155-part-1 rows).
read_last_field() {
  local field="$1"
  awk -v field="$field" '
    /^  - commit:/ { in_entry=1 }
    in_entry {
      pat = "^[[:space:]]+" field ":[[:space:]]+"
      if ($0 ~ pat) {
        v=$2; gsub(/[^0-9]/, "", v); if (v != "") last=v
      }
    }
    END { if (last == "") print 0; else print last }
  ' "$YAML" 2>/dev/null
}

prev_manifest=$(read_last_field "total")
prev_debt=$(read_last_field "runtime_debt_trackable")
prev_adr_req=$(read_last_field "runtime_adr_required")
prev_internal=$(read_last_field "runtime_internal")
prev_gated=$((prev_manifest + prev_debt + prev_adr_req))

delta=$((cur_gated - prev_gated))

# --- report --------------------------------------------------------------

echo "=== skip-impl ratchet (per ADR-0050 D-5 + D-6, ADR-0078 D-155 part 1) ==="
printf "%-28s %-8s %-8s %s\n" "metric" "prev" "cur" "note"
printf "%-28s %-8s %-8s %s\n" "manifest_total"        "$prev_manifest" "$manifest_total" "gated"
printf "%-28s %-8s %-8s %s\n" "runtime_debt_trackable" "$prev_debt"    "$cur_debt"       "gated"
printf "%-28s %-8s %-8s %s\n" "runtime_adr_required"   "$prev_adr_req" "$cur_adr_req"    "gated"
printf "%-28s %-8s %-8s %s\n" "runtime_internal"       "$prev_internal" "$cur_internal"  "informational"
printf "%-28s %-8s %-8s %s\n" "gated_total"            "$prev_gated"   "$cur_gated"      "= manifest + debt + ADR-req"
echo "delta (gated): $delta"
if [ -n "$unknown_lines" ]; then
  echo ""
  echo "WARN — runtime SKIP-* tokens not in ADR-0078 table:"
  printf '%s\n' "$unknown_lines" | sed 's/^/  /'
  echo "Fix: add a row to ADR-0078's canonical table OR remove the runner emission."
fi
echo ""

if [ "$delta" -le 0 ]; then
  echo "[check_skip_impl_ratchet] OK — ratchet not violated"
  exit 0
fi

# --- regression: require exempt ADR in the same commit -------------------

has_exempt_in_diff() {
  local diff_target="$1"
  git diff "$diff_target" --unified=0 -- "$YAML" 2>/dev/null \
    | grep -qE '^\+[[:space:]]+exempt:[[:space:]]+ADR-[0-9]+'
}

if has_exempt_in_diff "--cached" || has_exempt_in_diff "HEAD~1..HEAD"; then
  echo "[check_skip_impl_ratchet] OK — regression has exempt: ADR-NNNN row"
  exit 0
fi

if [ "$MODE" = "--gate" ]; then
  echo "[check_skip_impl_ratchet] FAIL — gated skip-count rose by +$delta without exempt: ADR-NNNN"
  echo "[check_skip_impl_ratchet] Fix: (a) close the regression, OR"
  echo "                          (b) add a new yaml row with exempt: <ADR-NNNN>"
  echo "                              citing an Accepted ADR that justifies the increase."
  exit 1
fi

echo "[check_skip_impl_ratchet] WARN — would FAIL in --gate mode"
exit 0
