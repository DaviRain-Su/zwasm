#!/usr/bin/env bash
# Regenerate the SIMD spec assertion corpus (§9.9 per ADR-0045).
#
# wast2json bakes binary modules + commands JSON; this script
# distills the JSON into the v128-aware extended manifest format
# the simd_assert_runner consumes:
#
#   module <file>                                   → load .wasm
#   assert_return <fn> <args> -> <results>          → invoke + compare
#
# args / results format (per ADR-0045 §"Decision" / 2):
#   <type>:<value>  for scalars (i32:13, f64:0x3ff8000000000000)
#   v128:<32 hex>   for v128 bit-pattern (big-endian hex digits;
#                   in-memory layout is little-endian per Wasm spec)
#
# §9.9-a (this commit) — **foundation**: script skeleton + corpus
# directory layout. NAMES list is empty; no manifests generated
# yet. §9.9-b adds the lightweight starter set (simd_address,
# simd_align, simd_const, simd_select, splat ops).

set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM=${WASM_TESTSUITE_REPO:-$HOME/Documents/OSS/WebAssembly/testsuite}
DEST=test/spec/wasm-2.0-simd-assert

# SIMD fixtures live at the testsuite root (not proposals/simd/);
# the SIMD proposal merged into core wasm-2.0 in 2021. ~57 simd*.wast
# files at the testsuite root.
if ! ls "$UPSTREAM"/simd_*.wast >/dev/null 2>&1; then
  echo "[regen_spec_simd_assert] no simd_*.wast files in $UPSTREAM" >&2
  exit 1
fi

# §9.9-b will populate. Lightweight starter set candidates per
# the §9.9 survey (private/notes/p9-9.9-survey.md):
#   simd_address    (46 assertions)
#   simd_align      (54 assertions)
#   simd_const      (lightweight)
#   simd_select     (6 assertions)
#   simd_splat ops  (per-shape splat fixtures)
NAMES=(
)

mkdir -p "$DEST"

if [ ${#NAMES[@]} -eq 0 ]; then
  echo "[regen_spec_simd_assert] §9.9-a foundation: 0 fixtures wired"
  echo "[regen_spec_simd_assert] §9.9-b will populate NAMES with the lightweight starter set"
  exit 0
fi

echo "[regen_spec_simd_assert] would regenerate ${#NAMES[@]} fixtures (NOT YET IMPLEMENTED — stub)"
exit 1
