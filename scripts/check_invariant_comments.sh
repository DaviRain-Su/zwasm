#!/usr/bin/env bash
# Lint for prose-only register-pool invariants that comments claim but
# code-level enforcement does not back. Surfaces the D-132 /
# regalloc-pool-scratch-overlap failure mode where source comments
# asserted "X10/X11/X12 are private scratch" while those slots were
# simultaneously in `abi.allocatable_caller_saved_scratch_gprs`.
#
# Scope (arm64 only for now; x86_64 caller_saved pool is currently
# empty per abi.zig):
#   - For each per-arch arm64 op_*.zig source under
#     `src/engine/codegen/arm64/`, find hardcoded register numerals N
#     in `encLdr*(N, ...)` / `encStr*(N, ...)` / etc. where N is a
#     member of arm64 abi's `allocatable_caller_saved_scratch_gprs`.
#   - Each such site is a *latent* D-133-class issue: regalloc may
#     assign a vreg to that slot, and the op-internal hardcoded use
#     clobbers it.
#
# This is preventive: most current sites have no concrete trigger
# (per D-133 row body). Surfacing the count keeps the latent debt
# visible.
#
# Usage:
#   bash scripts/check_invariant_comments.sh          # warn only
#   bash scripts/check_invariant_comments.sh --strict # exit 1 if any
#
# Future extensions (cf. substrate audit Q5):
#   - x86_64 mirror once that abi's allocatable_caller_saved_scratch_gprs
#     is populated.
#   - Lint forbidden-phrase patterns ("for now we share X", "the same
#     field is reused") per single_slot_dual_meaning.md.
#   - Detect "/// X is reserved private scratch" comment + grep the
#     pool to verify the claim.

set -uo pipefail

cd "$(dirname "$0")/.."

strict=0
case "${1:-}" in
  --strict|--gate) strict=1 ;;
  "") ;;
  *) echo "usage: $0 [--strict|--gate]" >&2; exit 2 ;;
esac

# Extract the arm64 allocatable-caller-saved-scratch pool from abi.zig.
# The line shape is:
#   pub const allocatable_caller_saved_scratch_gprs = [_]Xn{ 9, 10, 11, 12, 13 };
abi=src/engine/codegen/arm64/abi.zig
pool_line=$(grep -E 'pub const allocatable_caller_saved_scratch_gprs\s*=' "$abi")
if [ -z "$pool_line" ]; then
  echo "ERROR: cannot locate allocatable_caller_saved_scratch_gprs in $abi" >&2
  exit 2
fi

# Strip everything outside the `{ ... }` bytes-list, then split on
# commas, trim whitespace. e.g. "9, 10, 11, 12, 13" → "9\n10\n11\n12\n13".
pool_nums=$(echo "$pool_line" \
  | sed -E 's/.*\{([^}]*)\}.*/\1/' \
  | tr ',' '\n' \
  | sed -E 's/[[:space:]]//g' \
  | grep -E '^[0-9]+$')

if [ -z "$pool_nums" ]; then
  echo "ERROR: could not parse pool member numbers from: $pool_line" >&2
  exit 2
fi

# Build a regex alternation: ^(9|10|11|12|13)$
pool_re=$(echo "$pool_nums" | paste -sd'|' -)
echo "arm64 allocatable_caller_saved_scratch_gprs = { $(echo "$pool_nums" | tr '\n' ' ') }"

# Sites worth scanning. Keep narrow — op_*.zig are the chunks D-133
# explicitly enumerates.
files=$(find src/engine/codegen/arm64 -name 'op_*.zig' -type f 2>/dev/null)

total=0
echo ""
echo "Hardcoded-register sites in op_*.zig that overlap the pool:"

for f in $files; do
  # Patterns of interest: enc<Op>(N, ...) where N is a bare integer.
  # Common ops: encLdrImm, encStrImm, encLdrImmW, encStrImmW,
  # encLdrXRegLsl3, encStrXRegLsl3, encMovzImm16, encMovReg, encOrrRegW,
  # encAddReg, encCmpRegX, encCmpImmW, ...
  matches=$(grep -nE 'inst\.enc[A-Z][a-zA-Z]*\(\s*('"$pool_re"')\s*,' "$f" \
            || true)
  if [ -n "$matches" ]; then
    count=$(echo "$matches" | wc -l | tr -d ' ')
    echo ""
    echo "  $f: $count site(s)"
    echo "$matches" | sed 's/^/    /'
    total=$((total + count))
  fi
done

echo ""
echo "Total: $total latent overlap site(s) (D-133 tracks this; substrate audit Q5 anchor)."

# Forbidden-phrase patterns per .claude/rules/single_slot_dual_meaning.md.
# Code comments using "the same X is reused" or "for now we share X"
# normalise the dual-axis-merge anti-pattern. Flag occurrences.
echo ""
echo "Forbidden-phrase patterns in code comments (single_slot_dual_meaning.md):"
forbidden_phrases='the same field is reused|for now we share|reusing the same slot for both|share this field for both'
phrase_hits=$(grep -rEn --include='*.zig' "//.*($forbidden_phrases)" src/ 2>/dev/null || true)
phrase_total=0
if [ -n "$phrase_hits" ]; then
  phrase_total=$(echo "$phrase_hits" | wc -l | tr -d ' ')
  echo "$phrase_hits" | sed 's/^/  /'
fi
echo "Forbidden-phrase site(s): $phrase_total"

grand_total=$((total + phrase_total))
if [ "$strict" -eq 1 ] && [ "$grand_total" -gt 0 ]; then
  exit 1
fi
exit 0
