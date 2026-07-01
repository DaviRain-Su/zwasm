#!/usr/bin/env bash
# Mac-side gate runner with an UNAMBIGUOUS exit code.
#
# Why this exists: ad-hoc gate one-liners that tack a trailing
# `grep -cE "<pat>" "$log"` onto `zig build test-all` make the COMPOUND
# command exit 1 whenever the grep finds zero matches — that is grep's
# documented behaviour (exit 1 = "no lines selected"), NOT a build
# failure. The harness reports the compound command's exit code, so a
# green build surfaced as a false "command failed" task-notification and
# forced a manual "is this real?" disambiguation every time. This wrapper
# runs the scope-classified gate (+ the Mac-host lint gate), keeps every
# inspection grep OUT of the exit path, and exits 0 iff the build AND lint
# genuinely passed. It mirrors run_remote_ubuntu.sh's `[..] OK/FAIL`
# clean-exit contract for the local host.
#
# Usage:
#   bash scripts/mac_gate.sh                 # auto: classify_chunk_scope.sh
#   bash scripts/mac_gate.sh test            # force a step
#   bash scripts/mac_gate.sh test-all
#   MAC_GATE_LOG=/tmp/x.log bash scripts/mac_gate.sh
#
# After it returns, inspect the build output yourself by READING the log
# ($MAC_GATE_LOG, default /tmp/mac_gate.log) — never by appending a grep
# to this script's invocation (that reintroduces the footgun above).
set -uo pipefail
cd "$(dirname "$0")/.."

step="${1:-}"
if [ -z "$step" ]; then
    # ADR-0076 D1 scope→step mapping: substrate→test, else→test-all.
    class="$(bash scripts/classify_chunk_scope.sh 2>/dev/null | head -1 || true)"
    case "$class" in
        substrate*) step=test ;;
        *) step=test-all ;; # logic | cohort | unclear | empty → widest
    esac
fi

log="${MAC_GATE_LOG:-/tmp/mac_gate.log}"
: > "$log"
echo "[mac_gate] step=$step (log=$log)"

if ! timeout "${MAC_GATE_TIMEOUT:-600}" zig build "$step" >> "$log" 2>&1; then
    echo "[mac_gate] FAIL: zig build $step (read $log)"
    exit 1
fi
if ! timeout "${MAC_GATE_LINT_TIMEOUT:-300}" zig build lint -- --max-warnings 0 >> "$log" 2>&1; then
    echo "[mac_gate] FAIL: zig build lint (read $log)"
    exit 1
fi
echo "[mac_gate] OK (step=$step + lint; read $log to inspect)"
exit 0
