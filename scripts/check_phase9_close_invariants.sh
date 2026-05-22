#!/usr/bin/env bash
# scripts/check_phase9_close_invariants.sh
#
# Verify Phase 9 = DONE invariants I1-I7 per
# `.claude/rules/phase9_close_invariants.md` + `.dev/phase9_close_master.md` §6.
#
# A fresh /continue session reads this via Resume Step 5d to land on
# the truth: Phase 9 cannot close until the underlying Tier-1 work
# lands (SKIP-WIN64-* arms removed; c_api Wasm-2.0 utilisation tests
# present; Zig facade subset implemented; wast_runtime_runner wired;
# workaround-masquerade debts cleared; ADR-0105/0106 Accepted).
#
# Usage:
#   bash scripts/check_phase9_close_invariants.sh        # report mode
#   bash scripts/check_phase9_close_invariants.sh --gate # exit non-0 on any FAIL

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

echo "[check_phase9_close_invariants] running invariants I1-I7 ..."
echo

# I1 — Zero SKIP-WIN64-* token emission in spec runner
runner=test/spec/spec_assert_runner_base.zig
if [ ! -f "$runner" ]; then
  fail "I1: $runner not found"
else
  if grep -qE 'SKIP-WIN64-EXHAUSTION' "$runner"; then
    fail "I1: SKIP-WIN64-EXHAUSTION arm still in $runner (D-162 not closed; ADR-0105 not implemented)"
  else
    ok "I1a: SKIP-WIN64-EXHAUSTION arm removed"
  fi
  if grep -qE 'SKIP-WIN64-CALL-INDIRECT-TRAP' "$runner"; then
    fail "I1: SKIP-WIN64-CALL-INDIRECT-TRAP arm still in $runner (D-163 not closed)"
  else
    ok "I1b: SKIP-WIN64-CALL-INDIRECT-TRAP arm removed"
  fi
  if grep -qE 'SKIP-WIN64-MULTI-RESULT' "$runner"; then
    fail "I1: SKIP-WIN64-MULTI-RESULT arm still in $runner (D-164 not closed; ADR-0106 not implemented)"
  else
    ok "I1c: SKIP-WIN64-MULTI-RESULT arm removed"
  fi
fi

# I2 — c_api Wasm-2.0 utilisation tests present
for f in test/api/c_api_wasm2_reftype.zig \
         test/api/c_api_wasm2_bulk_traps.zig \
         test/api/c_api_mixed_exports.zig; do
  if [ -f "$f" ]; then ok "I2: $f present"; else fail "I2: $f missing"; fi
done
if [ -d test/runners/fixtures/cross_module_funcref ]; then
  ok "I2: test/runners/fixtures/cross_module_funcref/ present"
else
  fail "I2: test/runners/fixtures/cross_module_funcref/ missing"
fi

# I3 — Zig facade minimum subset in src/zwasm.zig
zwasm_zig=src/zwasm.zig
if [ ! -f "$zwasm_zig" ]; then
  fail "I3: $zwasm_zig not found"
else
  for sym in 'pub const Runtime' 'pub const Module' 'pub const Instance' 'pub const Value'; do
    if grep -qE "^$sym" "$zwasm_zig"; then
      ok "I3: $sym present in src/zwasm.zig"
    else
      fail "I3: $sym MISSING in src/zwasm.zig (ADR-0025 minimum subset; master plan §5.2)"
    fi
  done
fi
zig_facade_test=test/api/zig_facade_wasm2.zig
if [ -f "$zig_facade_test" ]; then
  ok "I3: $zig_facade_test present"
else
  fail "I3: $zig_facade_test missing"
fi

# I4 — wast_runtime_runner in test-all
# Check the explicit "NOT in test-all" marker comment first — wins over
# any partial substring match elsewhere in build.zig.
if grep -qE 'NOT in test-all|NOT YET aggregated into test-all' build.zig; then
  fail "I4: build.zig still carries 'NOT in test-all' comment for wast_runtime_runner (close per master plan §5.2)"
elif grep -qE 'test_all_step\.dependOn.*wast_runtime|test_all_step\.dependOn\(.*wast_runtime_smoke' build.zig; then
  ok "I4: wast_runtime_runner wired into test-all"
else
  fail "I4: wast_runtime_runner test-all wiring not detected"
fi

# I5 — Zero workaround-masquerade `trigger-not-fired` debts
# Match only Status: cells that legitimize the phrase (i.e. the row's
# blocking barrier IS "trigger-not-fired"). Exclude reframe notes that
# explicitly negate it ("not trigger-not-fired" / "NOT trigger-not-fired").
debt=.dev/debt.md
if [ ! -f "$debt" ]; then
  fail "I5: $debt not found"
else
  bad=$(grep -nE 'blocked-by:[^|]*trigger-not-fired' "$debt" | grep -vE 'not trigger-not-fired|NOT trigger-not-fired' || true)
  if [ -n "$bad" ]; then
    fail "I5: 'blocked-by: ... trigger-not-fired' workaround-masquerade still in debt.md (per ADR-0104 D3 reframe): $bad"
  else
    ok "I5: no 'trigger-not-fired' workaround-masquerade blocked-by rows in debt.md"
  fi
fi

# I6 — ADR-0105 + ADR-0106 Accepted
for adr in 0105_jit_prologue_stack_probe 0106_multi_result_return_convention; do
  f=".dev/decisions/${adr}.md"
  if [ ! -f "$f" ]; then
    fail "I6: $f missing"
    continue
  fi
  if grep -qE '^- \*\*Status\*\*: Accepted' "$f"; then
    ok "I6: $(basename "$f" .md) Status: Accepted"
  else
    status=$(grep -E '^- \*\*Status\*\*:' "$f" | head -1)
    fail "I6: $(basename "$f" .md) NOT Accepted yet — $status (user collab flip at §9.13 gate per ADR-0104 D1.6)"
  fi
done

# I7 — Master plan ACTIVE + handover points at it
mp=.dev/phase9_close_master.md
if [ ! -f "$mp" ]; then
  fail "I7: $mp not found"
else
  if grep -qE '\*\*Doc-state\*\*: ACTIVE' "$mp"; then
    ok "I7: master plan Doc-state: ACTIVE"
  else
    fail "I7: master plan does not declare Doc-state: ACTIVE"
  fi
fi
ho=.dev/handover.md
if [ -f "$ho" ] && grep -qE 'phase9_close_master\.md' "$ho"; then
  ok "I7: handover.md references master plan"
else
  fail "I7: handover.md does NOT reference phase9_close_master.md (P12 refresh missing)"
fi

# Report
echo
printf '%s\n' "${LINES[@]}"
echo
echo "[check_phase9_close_invariants] $((TOTAL - FAILS)) / $TOTAL passed, $FAILS failed"

if [ $GATE -eq 1 ] && [ $FAILS -gt 0 ]; then
  echo "[check_phase9_close_invariants] FAIL — Phase 9 NOT eligible to close until all invariants hold."
  echo "[check_phase9_close_invariants] See .claude/rules/phase9_close_invariants.md + .dev/phase9_close_master.md §6 + §5."
  exit 1
fi

if [ $FAILS -eq 0 ]; then
  echo "[check_phase9_close_invariants] OK — Phase 9 = DONE eligible (invariants I1-I7 satisfied)."
fi

exit 0
