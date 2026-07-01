#!/usr/bin/env bash
# scripts/regen_test_data.sh — regenerate derivative test data.
#
# Phase 1: bake the curated Wasm-1.0 (MVP) corpus into
#   test/spec/wasm-1.0/<name>.0.wasm via `wasm-tools json-from-wast`
#   (D-290: one modern CLI). `strip --all` drops wasm-tools' default
#   `name` custom section so output stays minimal (7/9 byte-identical to
#   the old wabt baseline; nop/unreachable differ +2B = wasm-tools'
#   extended element-segment encoding vs wabt's MVP flag=0 form — both
#   valid, parser handles both). Pin + curation: test/spec/wasm-1.0/README.md
#   per ADR-0002.
#
# Phase 4+: build realworld samples from C / Rust / Go sources.
# Phase 11+: build bench wasms.

set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM=${WASM_SPEC_REPO:-$HOME/Documents/OSS/WebAssembly/spec}
DEST=test/spec/wasm-1.0
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

if ! command -v wasm-tools >/dev/null 2>&1; then
  echo "[regen_test_data] wasm-tools not found (need it in PATH or dev shell)" >&2
  exit 1
fi

if [ ! -d "$UPSTREAM/test/core" ]; then
  echo "[regen_test_data] upstream not found at $UPSTREAM/test/core" >&2
  echo "[regen_test_data] set WASM_SPEC_REPO env var to override" >&2
  exit 1
fi

NAMES=(const forward labels local_get local_set nop switch unreachable unwind)

for n in "${NAMES[@]}"; do
  src="$UPSTREAM/test/core/$n.wast"
  if [ ! -f "$src" ]; then
    echo "[regen_test_data] missing $src" >&2
    exit 1
  fi
  ( cd "$TMP" && wasm-tools json-from-wast "$src" -o "$n.json" --wasm-dir . >/dev/null 2>&1 )
  wasm-tools strip --all "$TMP/$n.0.wasm" -o "$DEST/$n.0.wasm"
done

echo "[regen_test_data] regenerated ${#NAMES[@]} fixtures into $DEST/"
