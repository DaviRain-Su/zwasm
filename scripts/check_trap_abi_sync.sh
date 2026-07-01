#!/usr/bin/env bash
# C-ABI drift guard: the public `ZWASM_TRAP_*` constants in `include/zwasm.h`
# MUST match the `TrapKind` enum values in `src/api/trap_surface.zig` (the values
# `zwasm_trap_kind()` returns). C hosts switch on these numbers, so a silent enum
# reorder / header hand-edit would break them. @embedFile can't reach include/
# from the src package, so this cross-artifact check runs at the build-gate.
#
# Usage: check_trap_abi_sync.sh [--gate]   (exit 1 on mismatch with --gate)
set -euo pipefail
cd "$(dirname "$0")/.."

HDR=include/zwasm.h
SRC=src/api/trap_surface.zig

# Header → "<name_lower> <value>" (strip ZWASM_TRAP_ prefix, lowercase).
hdr=$(grep -oE '#define ZWASM_TRAP_[A-Z_]+ [0-9]+' "$HDR" \
  | sed -E 's/#define ZWASM_TRAP_([A-Z_]+) ([0-9]+)/\1 \2/' \
  | awk '{print tolower($1), $2}' | sort)

# Enum block → "<field> <value>" (drop the Zig-keyword trailing underscore, e.g.
# `unreachable_` → `unreachable`, to match the header spelling).
enum=$(awk '
  /pub const TrapKind = enum\(u32\) \{/ { f = 1; next }
  f && /^\};/ { exit }
  f && /^[ \t]+[a-z_]+ = [0-9]+,/ {
    gsub(/[ ,]/, ""); split($0, a, "="); name = a[1]; sub(/_$/, "", name);
    print name, a[2]
  }
' "$SRC" | sort)

if [ "$hdr" = "$enum" ]; then
  n=$(printf '%s\n' "$hdr" | grep -c .)
  echo "[check_trap_abi_sync] OK — $n ZWASM_TRAP_* constants match the TrapKind enum"
  exit 0
fi

echo "[check_trap_abi_sync] MISMATCH between $HDR and $SRC TrapKind:" >&2
diff <(printf '%s\n' "$enum") <(printf '%s\n' "$hdr") | sed 's/^/  /' >&2 || true
echo "  (< = enum value with no/disagreeing header #define; > = header #define with no/disagreeing enum value)" >&2
[ "${1:-}" = "--gate" ] && exit 1
exit 0
