#!/usr/bin/env bash
# Differential coverage sweep: run EVERY wasmtime tests/misc_testsuite/*.wast
# through zwasm's runtime-asserting WAST runner and tally pass/fail/skip.
# (ADR-0192 — wasmtime misc_testsuite full differential coverage campaign.)
#
# Unlike scripts/regen_wasmtime_misc.sh (hand-curated BATCH1-3 → committed
# corpus), this is the GAP-FINDER: it converts + runs all 312 .wast and
# writes a per-file verdict so each failure can be root-caused and fixed.
#
# Verdicts:
#   PASS      runner exit 0 (all runtime asserts held)
#   FAIL      runner exit !=0 (assert mismatch / validate / trap / crash)
#   CONVFAIL  wasm-tools json-from-wast rejected the .wast (unsupported text:
#             component-model syntax, bleeding-edge proposal, etc.)
#   EMPTY     converted, but no runtime directives distilled (e.g. all-v128
#             asserts the distiller drops — runner has nothing to check)
#
# Usage:
#   bash scripts/wasmtime_misc_sweep.sh [bucket ...]
#     bucket = a subdir under misc_testsuite (gc, simd, memory64, ...) or
#              "top" for the top-level (non-subdir) .wast files. Default: all.
#
# Output:
#   /tmp/wmt-sweep/summary.txt   per-file verdicts + bucket tallies
#   /tmp/wmt-sweep/<name>.log    runner output for FAIL files (root-cause)
set -uo pipefail
cd "$(dirname "$0")/.."

UPSTREAM=${WASMTIME_REPO:-$HOME/Documents/OSS/wasmtime}
MISC="$UPSTREAM/tests/misc_testsuite"
RUNNER=zig-out/bin/zwasm-wast-runtime-runner
OUT=/tmp/wmt-sweep
DISTIL=scripts/wast_to_manifest.py

command -v wasm-tools >/dev/null 2>&1 || { echo "wasm-tools not in PATH (nix develop .#gen)"; exit 1; }
[ -d "$MISC" ] || { echo "misc_testsuite not found at $MISC"; exit 1; }

echo "[sweep] building runner..."
zig build install >/dev/null 2>&1 || { echo "zig build failed"; exit 1; }
[ -x "$RUNNER" ] || { echo "runner not at $RUNNER after build"; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"
SUMMARY="$OUT/summary.txt"
: > "$SUMMARY"

# Collect target .wast paths (relative to $MISC) per requested buckets.
declare -a FILES
if [ "$#" -eq 0 ]; then
  while IFS= read -r f; do FILES+=("$f"); done < <(cd "$MISC" && find . -name '*.wast' | sed 's#^\./##' | sort)
else
  for b in "$@"; do
    if [ "$b" = top ]; then
      while IFS= read -r f; do FILES+=("$f"); done < <(cd "$MISC" && find . -maxdepth 1 -name '*.wast' | sed 's#^\./##' | sort)
    else
      while IFS= read -r f; do FILES+=("$f"); done < <(cd "$MISC" && find "$b" -name '*.wast' 2>/dev/null | sed 's#^\./##' | sort)
    fi
  done
fi

run_one() {
  local rel="$1"
  local src="$MISC/$rel"
  local tag; tag=$(echo "$rel" | sed 's#/#__#g; s#\.wast$##')
  local tmp; tmp=$(mktemp -d)
  local fix="$tmp/fix"
  mkdir -p "$fix"

  if ! ( cd "$tmp" && wasm-tools json-from-wast "$src" -o c.json --wasm-dir "$fix" >/dev/null 2>&1 ); then
    echo "CONVFAIL $rel" >> "$SUMMARY"; rm -rf "$tmp"; return
  fi
  python3 "$DISTIL" "$tmp/c.json" "$fix/manifest.txt" "$fix/manifest_runtime.txt" 2>"$tmp/distil.err" || {
    echo "CONVFAIL $rel (distil)" >> "$SUMMARY"; cp "$tmp/distil.err" "$OUT/$tag.log"; rm -rf "$tmp"; return
  }
  # Convert any .wat emissions to .wasm (valid text modules).
  for w in "$fix"/*.wat; do
    [ -e "$w" ] || continue
    wasm-tools parse "$w" -o "${w%.wat}.wasm" >/dev/null 2>&1 || true
  done
  # EMPTY = no runnable runtime directives (only module/skipped asserts).
  if ! grep -qE '^(assert_return|assert_trap|assert_unlinkable|assert_uninstantiable|invoke|register)' "$fix/manifest_runtime.txt" 2>/dev/null; then
    # still meaningful if it instantiates modules; mark EMPTY to flag low signal
    if ! grep -qE '^module ' "$fix/manifest_runtime.txt" 2>/dev/null; then
      echo "EMPTY $rel" >> "$SUMMARY"; rm -rf "$tmp"; return
    fi
  fi

  if timeout 60 "$RUNNER" "$tmp" >"$tmp/run.log" 2>&1; then
    echo "PASS $rel" >> "$SUMMARY"
  else
    echo "FAIL $rel" >> "$SUMMARY"
    cp "$tmp/run.log" "$OUT/$tag.log"
  fi
  rm -rf "$tmp"
}

echo "[sweep] running ${#FILES[@]} .wast files..."
for rel in "${FILES[@]}"; do run_one "$rel"; done

echo "" >> "$SUMMARY"
echo "=== tally ===" >> "$SUMMARY"
for v in PASS FAIL CONVFAIL EMPTY; do
  printf '%-9s %d\n' "$v" "$(grep -c "^$v " "$SUMMARY")" >> "$SUMMARY"
done
echo "[sweep] done -> $SUMMARY"
grep -A10 "=== tally ===" "$SUMMARY"
