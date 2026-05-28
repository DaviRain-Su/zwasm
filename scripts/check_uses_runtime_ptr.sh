#!/usr/bin/env bash
# scripts/check_uses_runtime_ptr.sh — drift detector for
# `src/engine/codegen/x86_64/usage.zig::usesRuntimePtr`.
#
# Per the D-180 lesson (`.dev/lessons/2026-05-28-x86_64-uses-runtime-
# ptr-eh-gap.md`): an x86_64 op whose emit produces R15-dependent
# bytes (load/store via `[R15+off]`, trampoline call, trap-stub
# fixup, runtime-callback CALL) MUST be in `usesRuntimePtr`'s
# whitelist OR the x86_64 prologue skips R15 setup → silent
# miscompile on Linux x86_64. Mac aarch64 is immune (always sets
# X19); this is a Linux-specific surface.
#
# Heuristic: scan each `src/engine/codegen/x86_64/ops/**/*.zig`
# file for patterns indicating R15 use (or trampoline-invoke), then
# cross-reference the file's `op_tag` against the usage.zig list.
# Emits WARN per gap candidate; reviewer confirms each.
#
# Usage:
#   bash scripts/check_uses_runtime_ptr.sh            # informational (always exit 0)
#   bash scripts/check_uses_runtime_ptr.sh --gate     # exit 1 on any gap
#
# False positives are expected (the heuristic is intentionally
# broad; e.g. an op that references R15 only in a `//` comment).
# Reviewer suppresses by adding the op to the whitelist OR by
# moving the R15 mention out of the file's lexical scope.

set -euo pipefail
cd "$(dirname "$0")/.."

GATE=0
if [ "${1:-}" = "--gate" ]; then
    GATE=1
fi

USAGE_FILE="src/engine/codegen/x86_64/usage.zig"
OPS_DIR="src/engine/codegen/x86_64/ops"

if [ ! -f "$USAGE_FILE" ]; then
    echo "[check_uses_runtime_ptr] FAIL: $USAGE_FILE not found" >&2
    exit 1
fi

# Extract the whitelisted op-tag set from usage.zig — strip
# `.@"..."` / `.foo` decorations down to bare op names.
mapfile -t WHITELIST < <(
    awk '/=> return true/{exit} /^pub fn usesRuntimePtr/{p=1; next} p' "$USAGE_FILE" \
        | grep -oE '\.@?"[a-z._0-9_]+"?|\.[a-z_][a-z0-9_]*' \
        | sed -E 's/^\.@?"?//; s/"$//' \
        | sort -u
)

is_whitelisted() {
    local op="$1"
    # Whitelist entries use dot-separated names (`ref.as_non_null`,
    # `memory.size`, `i32.load8_s`); filenames use underscore-only
    # (`ref_as_non_null`, `memory_size`, `i32_load8_s`). Normalize
    # both sides by replacing `.` → `_` for comparison.
    local op_norm="${op//./_}"
    for w in "${WHITELIST[@]}"; do
        local w_norm="${w//./_}"
        if [ "$w_norm" = "$op_norm" ]; then return 0; fi
    done
    return 1
}

# Scan each op file. For each, derive the op_tag (= filename
# without .zig + parent dir = wasm_X_Y/<op>.zig → tag derived
# by inverse of Zir's namespacing convention OR via `pub const
# op_tag = meta.op_tag;` then meta's enum value).
#
# Simpler: trust filename === op-tag-stem (matches the project's
# enforced convention; `dispatch_consistency_audit` skill verifies).

findings=0
while IFS= read -r f; do
    op="$(basename "$f" .zig)"
    # Trailing underscore is a Zig reserved-keyword escape
    # (e.g. `return_.zig` → `return`).
    op="${op%_}"

    # R15 references in code (not just comments). Heuristic:
    # match `r15` (case-insensitive) on lines that are NOT
    # pure `//` comments OR `///` docstrings.
    if ! grep -nE '^[^/]*[rR]15' "$f" >/dev/null 2>&1; then
        # Also check for trampoline invocation (which clobbers
        # R15 implicitly via the trampoline's own R15 read).
        if ! grep -nE 'zwasmThrowTrampoline|trampolineCore|memory_grow_fn|table_grow_fn|host_dispatch' "$f" >/dev/null 2>&1; then
            # Per lesson `2026-05-28-d180-detector-misses-bounds-
            # fixups.md` (10.R cycle 51): a per-op file that
            # registers a fixup against the function-end trap
            # stub is an IMPLICIT R15 user — the trap stub
            # emitted at function end reads R15. Three channels:
            # `bounds_fixups.append(...)` (memory bounds traps),
            # `unreach_fixups.append(...)` (unreachable / trap),
            # `sig_mismatch_fixups.append(...)` (call_indirect
            # sig check). Any of these = implicit R15 use.
            if ! grep -nE '\.(bounds_fixups|unreach_fixups|sig_mismatch_fixups)\.append' "$f" >/dev/null 2>&1; then
                continue
            fi
        fi
    fi

    # Op references R15 (or trampoline). Check whitelist.
    if ! is_whitelisted "$op"; then
        echo "[check_uses_runtime_ptr] WARN: op '$op' ($f) references R15 or runtime callback but is NOT in x86_64 usage.zig whitelist" >&2
        findings=$((findings + 1))
    fi
done < <(find "$OPS_DIR" -type f -name '*.zig')

if [ "$findings" -gt 0 ]; then
    echo "" >&2
    echo "[check_uses_runtime_ptr] $findings potential gap(s) — confirm + add to whitelist or suppress in code" >&2
    echo "[check_uses_runtime_ptr] See .dev/lessons/2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md" >&2
    if [ "$GATE" -eq 1 ]; then
        exit 1
    fi
fi

if [ "$findings" -eq 0 ]; then
    echo "[check_uses_runtime_ptr] OK — no drift detected" >&2
fi
exit 0
