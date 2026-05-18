#!/usr/bin/env bash
# scripts/check_build_dce.sh — Build-option DCE enforcement gate (skeleton)
#
# Build binaries for the 6 build-option combinations
# (`-Dwasm={v1_0,v2_0,v3_0}` × `-Dwasi={p1,p2}`) and verify via
# symbol table grep that no **forbidden** symbols remain in each build.
#
# Phase 9 completion master plan §7.1 / ADR-0071 + ADR-0073 (Proposed) landing point.
#
# Completion: §9.12-A enforcement layer construction phase.
# Current status: skeleton — only displays usage on `--help` + no-op invocation.
#
# Usage:
#   bash scripts/check_build_dce.sh                  # run all 6 combinations
#   bash scripts/check_build_dce.sh --sample <N>     # randomly sample N combinations
#   bash scripts/check_build_dce.sh --target <opt>   # run a single combination

set -uo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,17p' "$0"
  exit 0
fi

echo "[check_build_dce] skeleton — TODO(§9.12-A): implement full DCE check"
echo "[check_build_dce] expected behaviour:"
echo "  for each (-Dwasm=v1_0|v2_0|v3_0) × (-Dwasi=p1|p2):"
echo "    zig build -Dwasm=<lvl> -Dwasi=<lvl> -Doptimize=ReleaseSafe -p /tmp/zwasm-dce-<lvl>"
echo "    nm /tmp/zwasm-dce-<lvl>/bin/zwasm | grep -E 'wasm_(v128|gc|eh|tail)_' (per level)"
echo "    if any forbidden symbol present: FAIL with file:line introduced at"
echo ""
echo "[check_build_dce] (skeleton; exit 0)"
exit 0
