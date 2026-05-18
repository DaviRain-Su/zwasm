#!/usr/bin/env bash
# scripts/check_skip_impl_ratchet.sh — Skip-impl one-way ratchet (skeleton)
#
# pre-push hook + CI で fire。現 commit の skip-impl 数を
# `bench/results/skip_impl_history.yaml` の前 commit 値と比較し、
# **増えていたら FAIL**。例外は ADR で justify + yaml に `exempt:
# <ADR-NNNN>` 登録。
#
# Phase 9 完備 マスター計画書 §7.3 / ADR-0050 amend (D-3 / D-4) 着地点。
#
# 完成: §9.12-A enforcement layer 構築フェーズ。
# 現状: skeleton — `--help` + no-op invocation で usage 表示のみ。

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
