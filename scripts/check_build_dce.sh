#!/usr/bin/env bash
# scripts/check_build_dce.sh — Build-option DCE 強制 gate (skeleton)
#
# 6 build option 組合せ (`-Dwasm={v1_0,v2_0,v3_0}` × `-Dwasi={p1,p2}`) で
# binary を build し、各 build に **存在してはいけない** シンボルが残って
# いないか symbol table grep で確認する。
#
# Phase 9 完備 マスター計画書 §7.1 / ADR-0071 + ADR-0073 (Proposed) 着地点。
#
# 完成: §9.12-A enforcement layer 構築フェーズ。
# 現状: skeleton — `--help` + no-op invocation で usage 表示のみ。
#
# Usage:
#   bash scripts/check_build_dce.sh                  # 全 6 組合せ run
#   bash scripts/check_build_dce.sh --sample <N>     # ランダム N 組合せ抜き取り
#   bash scripts/check_build_dce.sh --target <opt>   # 1 組合せのみ run

set -uo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,17p' "$0"
  exit 0
fi

echo "[check_build_dce] skeleton — TODO(§9.12-A): implement full DCE check"
echo "[check_build_dce] expected behaviour:"
echo "  for each (-Dwasm=v1_0|v2_0|v3_0) × (-Dwasi=p1|p2):"
echo "    zig build -Dwasm=<lvl> -Dwasi=<lvl> -Doptimize=ReleaseSafe -p /tmp/zwasm-dce-<lvl>"
echo "    nm /tmp/zwasm-dce-<lvl>/bin/zwasm | grep -E 'wasm_(v128|gc|eh|tail)_' (level に応じ)"
echo "    if any forbidden symbol present: FAIL with file:line introduced at"
echo ""
echo "[check_build_dce] (skeleton; exit 0)"
exit 0
