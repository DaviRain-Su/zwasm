#!/usr/bin/env bash
# scripts/check_wasm_h_upstream.sh — verify include/wasm.h is in
# sync with the upstream WebAssembly/wasm-c-api header.
#
# Phase 10 prep deliverable per ROADMAP §9.12-G (e). The C ABI
# header lands verbatim from upstream; this script is the periodic
# drift detector.
#
# Usage:
#   bash scripts/check_wasm_h_upstream.sh          # report; exit 0 always
#   bash scripts/check_wasm_h_upstream.sh --gate   # exit 1 on drift

set -u

cd "$(dirname "$0")/.."

LOCAL="include/wasm.h"
UPSTREAM="${ZWASM_WASM_C_API_PATH:-$HOME/Documents/OSS/wasm-c-api}/include/wasm.h"

MODE="${1:-info}"

if [ ! -f "$LOCAL" ]; then
    echo "[check_wasm_h_upstream] FAIL — local $LOCAL missing" >&2
    [ "$MODE" = "--gate" ] && exit 1
    exit 0
fi

if [ ! -f "$UPSTREAM" ]; then
    echo "[check_wasm_h_upstream] SKIP — upstream $UPSTREAM not present" >&2
    echo "[check_wasm_h_upstream] (set ZWASM_WASM_C_API_PATH to override or clone WebAssembly/wasm-c-api into ~/Documents/OSS/wasm-c-api/)" >&2
    exit 0
fi

if diff -q "$LOCAL" "$UPSTREAM" > /dev/null 2>&1; then
    echo "[check_wasm_h_upstream] OK — $LOCAL byte-identical to upstream"
    exit 0
fi

# Drift detected — show full diff to stderr
echo "[check_wasm_h_upstream] DRIFT — $LOCAL differs from upstream:" >&2
diff -u "$UPSTREAM" "$LOCAL" >&2

if [ "$MODE" = "--gate" ]; then
    exit 1
fi
exit 0
