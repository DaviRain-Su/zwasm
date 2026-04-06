#!/usr/bin/env bash
# run_static_link_test.sh — Test linking libzwasm.a from non-Zig toolchains
#
# Simulates real-world usage: build static lib with PIC + compiler_rt,
# then link with system cc and cargo (Rust) directly.
#
# Usage:
#   bash test/c_api/run_static_link_test.sh [--build]
#
# Options:
#   --build   Force rebuild of static library (default: skip if exists)

set -euo pipefail
cd "$(dirname "$0")/../.."

BUILD=false
for arg in "$@"; do
    case "$arg" in
        --build) BUILD=true ;;
    esac
done

LIB="zig-out/lib/libzwasm.a"
PASS=0
FAIL=0
TOTAL=0

pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); echo "  FAIL: $1"; }

# --- Build static library with PIC + compiler_rt ---
if $BUILD || [ ! -f "$LIB" ]; then
    echo "Building static library (PIC + compiler_rt)..."
    zig build static-lib -Dpic=true -Dcompiler-rt=true
fi

echo ""
echo "=== Static Link Tests ==="
echo ""

# --- Test 1: C direct link with system cc ---
echo "[1/3] C direct link (cc)"
TMPBIN=$(mktemp /tmp/zwasm_static_XXXXXX)
if cc -o "$TMPBIN" examples/c/hello.c -Iinclude "$LIB" -lc -lm 2>/tmp/zwasm_cc_err.txt; then
    OUTPUT=$("$TMPBIN" 2>&1)
    if [ "$OUTPUT" = "f() = 42" ]; then
        pass "cc link + run"
    else
        fail "cc link ok but output='$OUTPUT' (expected 'f() = 42')"
    fi
else
    fail "cc link failed: $(cat /tmp/zwasm_cc_err.txt)"
fi
rm -f "$TMPBIN" /tmp/zwasm_cc_err.txt

# --- Test 2: C direct link with system cc (PIE) ---
echo "[2/3] C direct link (cc -pie)"
TMPBIN=$(mktemp /tmp/zwasm_static_XXXXXX)
PIE_FLAG=""
if [[ "$(uname)" != "Darwin" ]]; then
    PIE_FLAG="-pie"
fi
if cc $PIE_FLAG -o "$TMPBIN" examples/c/hello.c -Iinclude "$LIB" -lc -lm 2>/tmp/zwasm_cc_pie_err.txt; then
    OUTPUT=$("$TMPBIN" 2>&1)
    if [ "$OUTPUT" = "f() = 42" ]; then
        pass "cc PIE link + run"
    else
        fail "cc PIE link ok but output='$OUTPUT' (expected 'f() = 42')"
    fi
else
    fail "cc PIE link failed: $(cat /tmp/zwasm_cc_pie_err.txt)"
fi
rm -f "$TMPBIN" /tmp/zwasm_cc_pie_err.txt

# --- Test 3: Rust static link (cargo) ---
echo "[3/3] Rust static link (cargo)"
if command -v cargo >/dev/null 2>&1; then
    # Clean to avoid stale cached dylib-linked binary
    cargo clean --manifest-path examples/rust/Cargo.toml 2>/dev/null || true
    if ZWASM_STATIC=1 cargo build --manifest-path examples/rust/Cargo.toml 2>/tmp/zwasm_cargo_err.txt; then
        OUTPUT=$(ZWASM_STATIC=1 cargo run --manifest-path examples/rust/Cargo.toml 2>&1)
        if echo "$OUTPUT" | grep -q "f() = 42"; then
            pass "cargo static link + run"
        else
            fail "cargo build ok but output='$OUTPUT' (expected 'f() = 42')"
        fi
    else
        fail "cargo build failed: $(cat /tmp/zwasm_cargo_err.txt)"
    fi
    rm -f /tmp/zwasm_cargo_err.txt
else
    echo "  SKIP: cargo not found"
fi

# --- Summary ---
echo ""
echo "=== Summary: $PASS passed, $FAIL failed (of $TOTAL) ==="

exit $FAIL
