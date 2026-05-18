#!/usr/bin/env bash
# scripts/check_fallback_patterns.sh — Anti-fallback / anti-silent-degradation
# pattern detector (skeleton).
#
# pre-commit hook: greps `src/**/*.zig` for forbidden silent-degradation
# patterns per `.claude/rules/no_fallback_on_failure.md`:
#
#   - `catch \|err\| return null`
#   - `catch \|err\| .default_value`
#   - `catch \|err\| switch (err) { else => continue }`
#   - `catch {}` (= fully silent)
#   - new runtime emission of `SKIP-*` tokens (= bypassing skip-impl ratchet)
#
# Phase 9 completion master plan §7.4 / ADR-0071 + ADR-0050 amend landing.
#
# Status: skeleton (2026-05-19) — completed in §9.12-A enforcement layer
# build-out phase. Currently exits 0 with usage hint.

set -uo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,17p' "$0"
  exit 0
fi

echo "[check_fallback_patterns] skeleton — TODO(§9.12-A): implement grep checks"
echo "[check_fallback_patterns] expected behaviour:"
echo "  grep -nE 'catch \\{\\}' src/ → FAIL with file:line"
echo "  grep -nE 'catch \\|.*\\| return (null|undefined)' src/ → FAIL"
echo "  grep -nE 'catch \\|.*\\| .[a-z_]+_default' src/ → WARN"
echo "  grep -nE 'try stdout.print\\(\"SKIP-[A-Z-]+' src/ test/ → cross-check with ADR-0050 ratchet exempt list"
echo ""
echo "[check_fallback_patterns] (skeleton; exit 0)"
exit 0
