#!/usr/bin/env bash
# Classify the current chunk's scope for the autonomous loop's
# per-chunk FOREGROUND Mac test gate (per ADR-0076 D1).
#
# NOTE (ADR-0076 D6): this class drives the Mac gate ONLY. The
# background ubuntu gate is unconditionally `zig build test-all` and
# does NOT consult this script — once D5-b stopped the loop waiting on
# ubuntu, narrow scope there saved no loop wall-clock but skipped the
# x86_64-RUN spec/edge runners (the D-260 foot-gun). So the "Gate:"
# notes below are the Mac mapping; ubuntu = always test-all.
#
# Reads the staged + unstaged diff against HEAD and prints ONE of:
#
#   substrate   — struct defs / init sites / imports only.
#                 Gate: `zig build test`.
#   logic       — new `pub fn emit*` / dispatch arm change /
#                 new per-op file under `ops/`. Gate: `zig build test-all`.
#   cohort      — 5+ ops touched (per-op files under
#                 `src/engine/codegen/{arm64,x86_64}/ops/*`).
#                 Gate: `zig build test-all`.
#   unclear     — heuristics didn't fire. Gate: `zig build test-all`
#                 (default-safe fallback per ADR-0076 Alternative A
#                 vs D trade-off).
#
# Consumed by the /continue skill's per-task TDD Step 5; LOOP.md
# does not maintain the judgement table in prose — this script is
# the rule (mirroring gate_commit.sh / zone_check.sh).
#
# Usage:
#   bash scripts/classify_chunk_scope.sh                 → prints class
#   bash scripts/classify_chunk_scope.sh --explain       → class + reason
#   bash scripts/classify_chunk_scope.sh --commit <sha>  → classify the single
#                                                          commit <sha>^..<sha>
#                                                          (retro-classify
#                                                          a closed chunk)
#
# Exit code is always 0 (informational). The caller maps the
# printed class to the gate command.

set -euo pipefail

cd "$(dirname "$0")/.."

MODE="class"
DIFF_RANGE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --explain) MODE="--explain"; shift ;;
        --commit) DIFF_RANGE="$2^..$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Default: combined staged + unstaged diff against HEAD. When nothing is
# diff'd against HEAD (= chunk is already committed and we want
# to retro-classify the last commit), fall back to HEAD~1..HEAD.
if [ -z "$DIFF_RANGE" ]; then
    if git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet HEAD 2>/dev/null; then
        DIFF_RANGE="HEAD~1..HEAD"
    else
        DIFF_RANGE="HEAD"
    fi
fi

# All paths changed in the diff range.
changed_paths=$(git diff --name-only "$DIFF_RANGE" 2>/dev/null || true)

# 0 — empty diff: caller hasn't staged anything. Fall back unclear.
if [ -z "$changed_paths" ]; then
    if [ "$MODE" = "--explain" ]; then
        echo "unclear: no changed paths against HEAD"
    else
        echo "unclear"
    fi
    exit 0
fi

# Heuristic counters.
new_per_op_files=0
new_emit_fns=0
dispatch_arm_changes=0
struct_only_changes=0
total_src_files=0
non_src_only=1

# Per-op files = under src/engine/codegen/{arm64,x86_64}/ops/.
# Counted both as "new files" (= cohort signal) and as logic signal.
while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in
        src/*.zig)
            total_src_files=$((total_src_files + 1))
            non_src_only=0
            ;;
        src/*)
            non_src_only=0
            ;;
    esac
    case "$p" in
        src/engine/codegen/arm64/ops/*|src/engine/codegen/x86_64/ops/*)
            new_per_op_files=$((new_per_op_files + 1))
            ;;
    esac
done <<< "$changed_paths"

# Diff body inspection — count new `pub fn emit` (= new emit fn)
# and changes in giant-switch dispatch arms.
diff_body=$(git diff "$DIFF_RANGE" -- 'src/**/*.zig' 2>/dev/null || true)
if [ -n "$diff_body" ]; then
    # Added lines (start with `+`, not `+++`) that declare a new
    # `pub fn emit*` — a new emit handler entry point.
    new_emit_fns=$(echo "$diff_body" \
        | grep -cE '^\+[[:space:]]*pub fn emit[A-Z]' || true)
    # Dispatch arm signal: added/removed lines that match the
    # giant-switch arrow pattern `.@"..." =>` or split-off forms.
    dispatch_arm_changes=$(echo "$diff_body" \
        | grep -cE '^[+-][[:space:]]+\.@"[a-z0-9_.]+",?[[:space:]]*(=>.*|$)' \
        || true)
fi

# Struct-only changes: every added line is one of:
#   - blank
#   - comment (//, ///, //!)
#   - import (`const X = @import(...)`)
#   - struct field decl (`name: Type,`)
#   - struct init field (`.name = value,`)
#   - opening / closing brace / paren
#   - struct/enum/union opener
#   - `pub const`, `pub fn init` (factory only)
# Heuristic: count added body lines and added "structural" lines.
if [ -n "$diff_body" ]; then
    added_lines=$(echo "$diff_body" | grep -cE '^\+[^+]' || true)
    structural_lines=$(echo "$diff_body" | grep -cE '^\+[[:space:]]*(//|///|//!|const [a-zA-Z_][a-zA-Z_0-9]* = @import|pub const |pub fn init|[a-zA-Z_][a-zA-Z_0-9]*: |\.[a-zA-Z_][a-zA-Z_0-9]* = |[[:space:]]*$|\}|\{|return \.\{)' || true)
    if [ "$added_lines" -gt 0 ] && [ "$structural_lines" -ge $((added_lines * 9 / 10)) ]; then
        struct_only_changes=1
    fi
fi

# Decision tree.
class="unclear"
reason="heuristics did not fire"

if [ "$new_per_op_files" -ge 5 ]; then
    class="cohort"
    reason="$new_per_op_files per-op files touched (≥ 5)"
elif [ "$new_emit_fns" -ge 1 ] || [ "$new_per_op_files" -ge 1 ] || [ "$dispatch_arm_changes" -ge 2 ]; then
    class="logic"
    reason="new_emit_fns=$new_emit_fns new_per_op_files=$new_per_op_files dispatch_arm_changes=$dispatch_arm_changes"
elif [ "$struct_only_changes" = "1" ] && [ "$total_src_files" -ge 1 ]; then
    class="substrate"
    reason="struct/init/import-only diff across $total_src_files src/*.zig files"
elif [ "$non_src_only" = "1" ]; then
    class="substrate"
    reason="no src/*.zig changes (docs / config / scripts only)"
fi

if [ "$MODE" = "--explain" ]; then
    echo "$class: $reason"
else
    echo "$class"
fi
