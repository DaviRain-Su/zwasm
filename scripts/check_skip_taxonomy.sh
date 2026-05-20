#!/usr/bin/env bash
# scripts/check_skip_taxonomy.sh — Validate SKIP-* emissions against ADR-0078.
#
# Per ADR-0078 (spec runner SKIP-* token taxonomy) and D-155 follow-up:
# every `SKIP-<TOKEN>` emission in test/spec/ source MUST have a row in the
# ADR-0078 canonical table. A SKIP token landing without a class entry is
# `audit_scaffolding §G.1.1` `block` (re-derives the close-plan C3 failure
# mode: tokens landing without a paired ADR / debt artifact).
#
# Usage:
#   bash scripts/check_skip_taxonomy.sh         # report mode (exit 0)
#   bash scripts/check_skip_taxonomy.sh --gate  # exit 1 on miss
#
# Sibling: scripts/check_skip_impl_ratchet.sh (per-class gate semantics
# extension is D-155 part 1; this script is D-155 part 2).

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ADR="$ROOT/.dev/decisions/0078_spec_runner_skip_token_taxonomy.md"
if [ ! -f "$ADR" ]; then
  echo "[check_skip_taxonomy] FAIL — $ADR not found"
  exit 1
fi

MODE="${1:-report}"

# Extract canonical tokens from ADR-0078 table rows. Table rows start
# with `| \`SKIP-<NAME>\` |`; tolerate camelCase (SKIP-V2-InstanceAllocFailed).
adr_tokens=$(awk '
  /^\| `SKIP-/ {
    if (match($0, /SKIP-[A-Za-z][A-Za-z0-9_-]*/))
      print substr($0, RSTART, RLENGTH)
  }
' "$ADR" | sort -u)

# Extract emitted tokens from runner sources.
emitted_tokens=$(grep -rhoE '"SKIP-[A-Za-z][A-Za-z0-9_-]*' test/spec/ 2>/dev/null \
  | sed 's/^"//' | sort -u)

missing=$(comm -23 <(echo "$emitted_tokens") <(echo "$adr_tokens"))
inventory_only=$(comm -13 <(echo "$emitted_tokens") <(echo "$adr_tokens"))

emitted_count=$(echo "$emitted_tokens" | grep -c '^SKIP-' || true)
adr_count=$(echo "$adr_tokens" | grep -c '^SKIP-' || true)

echo "=== SKIP-* taxonomy gate (ADR-0078 / D-155 part 2) ==="
echo "Emitted tokens: $emitted_count"
echo "ADR-0078 rows : $adr_count"

if [ -n "$inventory_only" ]; then
  echo ""
  echo "Inventory-only (in ADR-0078, not currently emitted):"
  echo "$inventory_only" | sed 's/^/  - /'
fi

if [ -z "$missing" ]; then
  echo ""
  echo "[check_skip_taxonomy] OK — all emitted tokens have ADR-0078 rows"
  exit 0
fi

echo ""
echo "[check_skip_taxonomy] BLOCK — emitted tokens lacking ADR-0078 row:"
echo "$missing" | sed 's/^/  - /'
echo ""
echo "Fix: add a row to ADR-0078's canonical table for each, with class"
echo "(debt-trackable / ADR-required / runner-internal) + paired artifact."

if [ "$MODE" = "--gate" ]; then
  exit 1
fi
exit 0
