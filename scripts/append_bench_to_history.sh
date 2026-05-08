#!/usr/bin/env bash
# scripts/append_bench_to_history.sh — helper used by .github/workflows/bench.yml
# (NOT used by interactive local runs — local users invoke run_bench.sh
# --phase-record directly).
#
# Two modes:
#
#   extract <history.yaml.before> <history.yaml.after> <fragment.yaml>
#     Diff two history.yaml snapshots (before and after a
#     --phase-record run) and emit the appended tail as a standalone
#     YAML fragment. Strips the leading blank-line separator so the
#     fragment is self-contained.
#
#   append <fragment.yaml> <history.yaml>
#     Concatenate the fragment to the end of history.yaml. A single
#     blank line separates entries, matching the shape that
#     scripts/run_bench.sh --phase-record produces.
#
# This script never edits historical rows — it is append-only by
# construction (per ROADMAP §A9).

set -euo pipefail

mode="${1:-}"
shift || true

case "$mode" in
    extract)
        before="${1:?history.yaml.before path required}"
        after="${2:?history.yaml.after path required}"
        fragment="${3:?fragment.yaml path required}"
        if [ ! -f "$after" ]; then
            echo "[append_bench_to_history] $after not found" >&2
            exit 1
        fi
        before_lines=0
        if [ -f "$before" ]; then
            before_lines=$(wc -l < "$before" | tr -d ' ')
        fi
        # Tail off the new entry. tail -n +N is 1-indexed; +1 means "from
        # line 1". after_lines may be smaller than before_lines only if
        # someone truncated history.yaml in CI, which is forbidden, so
        # we error on that.
        after_lines=$(wc -l < "$after" | tr -d ' ')
        if [ "$after_lines" -le "$before_lines" ]; then
            echo "[append_bench_to_history] no new entry in $after vs $before" >&2
            exit 2
        fi
        start=$((before_lines + 1))
        # Strip the leading blank-line separator that run_bench.sh
        # emits before each --phase-record entry. The fragment should
        # start at the `- date:` line.
        tail -n +"$start" "$after" | awk '/^- date:/{found=1} found' > "$fragment"
        if [ ! -s "$fragment" ]; then
            echo "[append_bench_to_history] empty fragment after extract" >&2
            exit 3
        fi
        echo "[append_bench_to_history] extracted entry to $fragment"
        ;;
    append)
        fragment="${1:?fragment.yaml path required}"
        history="${2:?history.yaml path required}"
        if [ ! -f "$fragment" ]; then
            echo "[append_bench_to_history] $fragment not found" >&2
            exit 1
        fi
        if [ ! -f "$history" ]; then
            echo "[append_bench_to_history] $history not found" >&2
            exit 1
        fi
        printf '\n' >> "$history"
        cat "$fragment" >> "$history"
        echo "[append_bench_to_history] appended $fragment to $history"
        ;;
    *)
        echo "usage: $0 extract <history.yaml.before> <history.yaml.after> <fragment.yaml>" >&2
        echo "       $0 append  <fragment.yaml> <history.yaml>" >&2
        exit 64
        ;;
esac
