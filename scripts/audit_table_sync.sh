#!/usr/bin/env bash
# audit_table_sync.sh — enforce dual-view table storage sync invariant
# per ADR-0068 §A1.
#
# Replaces the aspirational `.claude/rules/dual_view_table_sync.md`
# (deleted 2026-05-25 alongside the orphan
# `src/engine/codegen/shared/table_storage.zig` scaffold) with a
# mechanical check. The rule's promised `audit_scaffolding §F grep`
# was never implemented; this script is its replacement.
#
# ## Invariant
#
# Every WRITING handler in `src/engine/codegen/{arm64,x86_64}/
# op_table.zig` — i.e. `emitTableSet` / `emitTableCopy` /
# `emitTableInit` / `emitTableGrow` / `emitTableFill` (Get and Size
# are read-only and exempt) — must be in ONE of these compliant
# shapes:
#
# (a) **Inline mirror**: body references BOTH `tables_ptr_off`
#     (refs view) AND `tables_jit_ci_ptr_off` (funcptr_base +
#     typeidx_base mirror).
# (b) **Runtime delegation**: body calls into a runtime helper
#     via `table_<op>_fn_off` (the runtime helper internally
#     maintains the mirror; codegen-side is exempt).
# (c) **Thin wrapper**: body is `return <call>(...);` only — the
#     `Ctx`-suffixed shim variants forward to (a) or (b) impls.
#
# A handler matching NONE of (a)/(b)/(c) re-introduces D-126: the
# refs view is updated without the funcptr/typeidx mirror, so
# post-mutation `call_indirect` reads stale funcptr_base + cross-
# instance dispatch fails silently.
#
# ## Why a static-grep + not a type check
#
# Zig's type system cannot express "every STR to refs slot is paired
# with an STR to funcptr_base in the same scope". The discipline is
# code-shape-level (= per-handler emit pattern), not type-level. The
# grep gate is the cheapest mechanical proxy.
#
# ## Exit codes
#
# - 0 — all writers compliant (or report mode).
# - 1 — at least one writer violates; prints handler + which
#       compliance criterion is missing.
#
# ## Usage
#
#   bash scripts/audit_table_sync.sh           # report (always exit 0)
#   bash scripts/audit_table_sync.sh --gate    # gate (exit non-0 on violation)
#
# ## Wiring
#
# Initially wired into `audit_scaffolding §F` (informational; surfaces
# at every audit invocation). Promotion to `gate_commit.sh` queued
# after 2+ clean audits — see ADR-0068 Revision history 2026-05-25.

set -euo pipefail
cd "$(dirname "$0")/.."

GATE_FLAG=0
for arg in "$@"; do
    case "$arg" in
        --gate) GATE_FLAG=1 ;;
        --help|-h)
            sed -n '1,/^set -euo/p' "$0" | head -n -1
            exit 0 ;;
    esac
done

GATE_FLAG="$GATE_FLAG" exec python3 - << 'PY'
import os, re, sys

GATE = os.environ.get("GATE_FLAG", "0") == "1"

# Files to check. Add new per-arch op_table.zig sources here as they land.
FILES = [
    "src/engine/codegen/arm64/op_table.zig",
    "src/engine/codegen/x86_64/op_table.zig",
]

# Writing handlers — mutating table ops per Wasm 2.0 spec §3.4.
# Get + Size are read-only and exempt; this regex must match every
# writing-handler family. Adding a new mutating op family requires
# updating this regex + ADR-0068's "Audit-prep configurations" in
# lockstep.
WRITER_RE = re.compile(r'^pub fn (emit(?:Table(?:Set|Copy|Init|Grow|Fill))(?:Ctx)?)\b')

# Base symbols + helper symbol fragment the compliance shapes look for.
REFS_BASE = "tables_ptr_off"
MIRROR_BASE = "tables_jit_ci_ptr_off"
RUNTIME_HELPER_RE = re.compile(r'\btable_[a-z_]+_fn_off\b')
THIN_WRAPPER_RE = re.compile(r'^\s*return\s+emit[A-Za-z]+\s*\(', re.MULTILINE)

def extract_function_body(lines, start_idx):
    """
    start_idx is 0-based index of the `pub fn ... {` line.
    Returns (body_lines, end_idx) where end_idx is the 0-based line of
    the closing `}`.
    Uses naive brace counting from the opening `{` on the start line.
    """
    depth = 0
    started = False
    for i in range(start_idx, len(lines)):
        for ch in lines[i]:
            if ch == '{':
                depth += 1
                started = True
            elif ch == '}':
                depth -= 1
                if started and depth == 0:
                    return lines[start_idx:i+1], i
    return lines[start_idx:], len(lines) - 1

def is_thin_wrapper(body_text):
    """A wrapper's body is essentially `return emitXxx(...);` — possibly
    multi-line. Detect by looking for `return emit...(` in the body
    AND no other meaningful statements (= no `try buf.append`, no
    encoder calls)."""
    # Has the wrapper-shaped return?
    has_return = bool(THIN_WRAPPER_RE.search(body_text))
    if not has_return:
        return False
    # Has any encoder-emit indicator? (= it's doing real codegen work)
    if re.search(r'\b(buf\.append|writeU32|enc[A-Z])', body_text):
        return False
    return True

violations = []
checked = 0

for path in FILES:
    if not os.path.isfile(path):
        print(f"[audit_table_sync] WARN: file not found: {path}", file=sys.stderr)
        continue
    with open(path) as f:
        lines = f.readlines()

    i = 0
    while i < len(lines):
        m = WRITER_RE.match(lines[i])
        if not m:
            i += 1
            continue
        fn_name = m.group(1)
        body, end_idx = extract_function_body(lines, i)
        body_text = "".join(body)
        checked += 1

        # Compliance check.
        is_wrapper = is_thin_wrapper(body_text)
        has_runtime_delegation = bool(RUNTIME_HELPER_RE.search(body_text))
        has_inline_mirror = (REFS_BASE in body_text) and (MIRROR_BASE in body_text)
        # Partial-inline = touches refs but not mirror → D-126 risk.
        has_refs_only = (REFS_BASE in body_text) and (MIRROR_BASE not in body_text)

        compliant = is_wrapper or has_runtime_delegation or has_inline_mirror
        if not compliant:
            shape = []
            if has_refs_only:
                shape.append("PARTIAL: references refs base but NOT mirror base (D-126 risk)")
            else:
                shape.append("UNKNOWN: references neither base + not a wrapper + no runtime helper call")
            violations.append((path, fn_name, i+1, end_idx+1, "; ".join(shape)))

        i = end_idx + 1

# Report.
for path, fn, ls, le, reason in violations:
    print(f"[audit_table_sync] VIOLATION: {path}::{fn} (L{ls}..{le}) — {reason}")
    print(f"  Compliance options per ADR-0068 §A1:")
    print(f"    (a) inline mirror: reference both `{REFS_BASE}` AND `{MIRROR_BASE}` in handler body")
    print(f"    (b) runtime delegation: call via `table_<op>_fn_off` helper")
    print(f"    (c) thin wrapper: body is `return emitXxx(...);` only")

print(f"[audit_table_sync] {checked} handler(s) checked, {len(violations)} violation(s) found")

if GATE and violations:
    print()
    print("[audit_table_sync] FAIL — at least one writing handler does not honor the dual-view sync invariant.")
    print("[audit_table_sync] See ADR-0068 §A1 Revision history 2026-05-25 + op_table.zig writing handlers.")
    sys.exit(1)
sys.exit(0)
PY
