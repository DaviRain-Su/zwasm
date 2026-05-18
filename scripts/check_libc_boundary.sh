#!/usr/bin/env bash
# scripts/check_libc_boundary.sh — libc dependency boundary lint (skeleton).
#
# Greps `src/**/*.zig` for new `std.c.*` call sites; cross-references each
# site with the 3-tier classification in ADR-0070 (necessary / replaceable /
# convenience). A new `std.c.<name>` call that is not in the necessary or
# convenience allowlist FAILs and emits a remediation hint to use
# `std.posix.<name>` / `process.Environ` / `std.os.linux.*` instead.
#
# Phase 9 completion master plan §3.6 / §7 / ADR-0070 (Proposed).
#
# Status: skeleton (2026-05-19) — completed in §9.12-D. Currently exits 0
# with usage hint.

set -uo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,15p' "$0"
  exit 0
fi

echo "[check_libc_boundary] skeleton — TODO(§9.12-D): implement boundary check"
echo "[check_libc_boundary] expected behaviour:"
echo "  1. grep -nE 'std\\.c\\.[a-z_]+\\(' src/ → enumerate all current call sites"
echo "  2. Cross-reference each site with ADR-0070's 3-tier classification"
echo "     - necessary (sigsetjmp / siglongjmp / pthread_jit_write_protect_np) → OK"
echo "     - replaceable (write / _exit / getenv / munmap / ...) → FAIL, suggest std.posix.*"
echo "     - convenience (DebugAllocator under Debug build) → OK"
echo "  3. New sites not in any tier → FAIL with remediation hint"
echo ""
echo "[check_libc_boundary] (skeleton; exit 0)"
exit 0
