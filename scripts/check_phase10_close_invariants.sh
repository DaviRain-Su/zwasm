#!/usr/bin/env bash
# scripts/check_phase10_close_invariants.sh
#
# Verify Phase 10 / 10.M = DONE invariants per ADR-0111 Revision
# (2026-05-25 user collab 1/7): the i64 memory64 emit code MUST be
# comptime-DCE'd from the `-Dwasm=v2_0` build, mechanically proving
# the comptime + runtime 2-stage gate (ADR-0111 D4) works as
# designed. Without DCE, a v2.0 build would carry dead memory64 code
# (binary size + i32 fast-path attack surface) — the gate verifies
# the comptime arm is structurally pruned, not just runtime-skipped.
#
# Currently checks I1 only (memory64 i64-arm DCE). Future Phase 10
# close invariants will land here as 10.M-* sub-chunks complete
# (10.R / 10.TC / 10.E / 10.G have their own close criteria).
#
# Usage:
#   bash scripts/check_phase10_close_invariants.sh        # report mode
#   bash scripts/check_phase10_close_invariants.sh --gate # exit non-0 on any FAIL
#
# Caveats:
#   - Builds with `-Dwasm=v2_0`; restores the default `-Dwasm=v3_0`
#     build cache slot on exit (zig caches per-options, so the next
#     `zig build` resumes the default cache without rebuild).
#   - Mac aarch64 host: checks arm64 emitMemOpI64. x86_64 host:
#     checks x86_64 emitMemOpI64 (the inactive arch is comptime-
#     pruned from the binary regardless of -Dwasm).
#   - Does NOT run tests; pairs with the host gate (`zig build
#     test-all`) for behaviour verification.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

GATE=0
if [ "${1:-}" = "--gate" ]; then GATE=1; fi

FAILS=0
TOTAL=0
LINES=()

fail() { LINES+=("FAIL  $1"); FAILS=$((FAILS+1)); TOTAL=$((TOTAL+1)); }
ok()   { LINES+=("OK    $1"); TOTAL=$((TOTAL+1)); }

echo "[check_phase10_close_invariants] running invariants ..."
echo

# I1 — memory64 i64-arm comptime-DCE under -Dwasm=v2_0 (ADR-0111
# Revision 2026-05-25 / D4 anchor). Build the CLI binary with
# -Dwasm=v2_0; nm-grep for emitMemOpI64 (private fn, file-scope
# symbol per Zig mangling); expect zero matches.
echo "[I1] building -Dwasm=v2_0 ..."
if ! zig build -Dwasm=v2_0 > /tmp/check_p10_build_v2.log 2>&1; then
  fail "I1: -Dwasm=v2_0 build failed; see /tmp/check_p10_build_v2.log"
else
  bin=zig-out/bin/zwasm
  if [ ! -x "$bin" ]; then
    fail "I1: $bin not found after -Dwasm=v2_0 build"
  else
    count=$(nm "$bin" 2>/dev/null | grep -cE 'emitMemOpI64\b' || true)
    if [ "$count" -eq 0 ]; then
      ok "I1: emitMemOpI64 absent from -Dwasm=v2_0 binary (count=0; comptime DCE confirmed)"
    else
      fail "I1: emitMemOpI64 leaked into -Dwasm=v2_0 binary (count=$count); comptime gate failed"
    fi
  fi
fi

# Restore default (v3_0) build cache slot so subsequent `zig build`
# doesn't rebuild from scratch.
zig build > /dev/null 2>&1 || true

# Report
echo
printf '%s\n' "${LINES[@]}"
echo
echo "[check_phase10_close_invariants] $((TOTAL - FAILS)) / $TOTAL passed, $FAILS failed"

if [ $GATE -eq 1 ] && [ $FAILS -gt 0 ]; then
  echo "[check_phase10_close_invariants] FAIL — Phase 10 / 10.M NOT eligible to close until all invariants hold."
  echo "[check_phase10_close_invariants] See ADR-0111 (D4 + Revision 2026-05-25)."
  exit 1
fi

if [ $FAILS -eq 0 ]; then
  echo "[check_phase10_close_invariants] OK — Phase 10 / 10.M close-eligible (invariants satisfied)."
fi

exit 0
