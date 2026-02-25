#!/usr/bin/env bash
# run_compat.sh — Compare zwasm vs wasmtime on real-world wasm programs
#
# Usage: bash test/realworld/run_compat.sh [--verbose]
#
# Requires: zwasm (zig-out/bin/zwasm) and wasmtime in PATH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WASM_DIR="$SCRIPT_DIR/wasm"

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
  esac
done

# Build zwasm if needed
if [ ! -f "$PROJECT_ROOT/zig-out/bin/zwasm" ]; then
  echo "Building zwasm..."
  (cd "$PROJECT_ROOT" && zig build -Doptimize=ReleaseSafe)
fi

ZWASM="$PROJECT_ROOT/zig-out/bin/zwasm"

PASS=0
FAIL=0
CRASH=0
TOTAL=0
RESULTS=""

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

run_test() {
  local wasm="$1"
  local name=$(basename "$wasm" .wasm)
  TOTAL=$((TOTAL + 1))

  local wasmtime_out="$TMP_DIR/${name}_wasmtime_out"
  local wasmtime_err="$TMP_DIR/${name}_wasmtime_err"
  local zwasm_out="$TMP_DIR/${name}_zwasm_out"
  local zwasm_err="$TMP_DIR/${name}_zwasm_err"

  # Determine extra args
  local extra_args=""
  local zwasm_flags="--allow-all"

  case "$name" in
    *hello_wasi*) extra_args="-- arg1 arg2" ;;
    *file_io*)    zwasm_flags="--allow-all" ;;
  esac

  # Run wasmtime
  local wt_exit=0
  if [[ "$name" == *file_io* ]]; then
    wasmtime run --dir /tmp "$wasm" $extra_args > "$wasmtime_out" 2> "$wasmtime_err" || wt_exit=$?
  else
    wasmtime run "$wasm" $extra_args > "$wasmtime_out" 2> "$wasmtime_err" || wt_exit=$?
  fi

  # Run zwasm
  local zw_exit=0
  $ZWASM run $zwasm_flags "$wasm" $extra_args > "$zwasm_out" 2> "$zwasm_err" || zw_exit=$?

  # Compare
  local status=""
  if [ $zw_exit -gt 128 ]; then
    status="CRASH"
    CRASH=$((CRASH + 1))
    RESULTS="$RESULTS\n  CRASH: $name (signal $((zw_exit - 128)))"
  elif diff -q "$wasmtime_out" "$zwasm_out" > /dev/null 2>&1; then
    if [ $wt_exit -eq $zw_exit ]; then
      status="PASS"
      PASS=$((PASS + 1))
    else
      status="EXIT_DIFF"
      FAIL=$((FAIL + 1))
      RESULTS="$RESULTS\n  EXIT_DIFF: $name (wasmtime=$wt_exit, zwasm=$zw_exit)"
    fi
  else
    status="DIFF"
    FAIL=$((FAIL + 1))
    RESULTS="$RESULTS\n  DIFF: $name"
    if [ $VERBOSE -eq 1 ]; then
      echo "    wasmtime stdout:"
      cat "$wasmtime_out" | head -20
      echo "    zwasm stdout:"
      cat "$zwasm_out" | head -20
      echo "    diff:"
      diff "$wasmtime_out" "$zwasm_out" | head -20 || true
    fi
  fi

  printf "  %-6s %s\n" "$status" "$name"
}

echo "=== Compatibility Test: zwasm vs wasmtime ==="
echo "zwasm: $($ZWASM --version 2>/dev/null || echo 'unknown')"
echo "wasmtime: $(wasmtime --version 2>/dev/null || echo 'unknown')"
echo ""

if [ ! -d "$WASM_DIR" ] || [ -z "$(ls "$WASM_DIR"/*.wasm 2>/dev/null)" ]; then
  echo "No wasm files found. Run build_all.sh first."
  exit 1
fi

for wasm in "$WASM_DIR"/*.wasm; do
  run_test "$wasm"
done

echo ""
echo "=== Summary ==="
echo "PASS: $PASS  FAIL: $FAIL  CRASH: $CRASH  TOTAL: $TOTAL"
if [ -n "$RESULTS" ] && [ $((FAIL + CRASH)) -gt 0 ]; then
  echo -e "Details:$RESULTS"
fi

exit $((FAIL + CRASH))
