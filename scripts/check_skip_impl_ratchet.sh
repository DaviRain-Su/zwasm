#!/usr/bin/env bash
# scripts/check_skip_impl_ratchet.sh — Skip-impl one-way ratchet (skeleton)
#
# Fires on pre-push hook + CI. Compares the current commit's
# skip-impl count against the previous commit value in
# `bench/results/skip_impl_history.yaml`, and **FAILs if it has
# increased**. Exceptions must be justified via ADR + registered
# in yaml as `exempt: <ADR-NNNN>`.
#
# Landing point for Phase 9 completeness master plan §7.3 / ADR-0050
# amend (D-3 / D-4).
#
# Completion: §9.12-A enforcement layer construction phase.
# Current state: skeleton — `--help` + no-op invocation only shows usage.

set -uo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,14p' "$0"
  exit 0
fi

echo "[check_skip_impl_ratchet] skeleton — TODO(§9.12-A): implement full ratchet"
echo "[check_skip_impl_ratchet] expected behaviour:"
echo "  1. Read prev skip-impl count from bench/results/skip_impl_history.yaml"
echo "  2. Run zig build test-spec-wasm-2.0-assert + test-spec-simd"
echo "  3. Extract current skip-impl count (non_simd + simd)"
echo "  4. If current > prev AND no 'exempt: ADR-NNNN' for this PR: FAIL"
echo "  5. Append new row to yaml with commit SHA + counts"
echo ""
echo "[check_skip_impl_ratchet] (skeleton; exit 0)"
exit 0
