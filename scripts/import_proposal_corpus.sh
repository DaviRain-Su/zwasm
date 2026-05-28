#!/usr/bin/env bash
# scripts/import_proposal_corpus.sh — fetch Wasm 3.0 proposal
# spec corpora from `~/Documents/OSS/WebAssembly/<proposal>/`
# (read-only reference clones; see `.dev/reference_clones.md`)
# into `test/spec/wasm-3.0-assert/<proposal>/raw/` for the
# wasm-3.0 assert runner (10.T-2) to consume.
#
# Companion script to `scripts/regen_spec_{1,2}_0_assert.sh`
# (which bake .wast → .wasm + manifest via wast2json + python
# JSON munging). This script does ONLY the upstream → raw
# copy + an existence/count check. The wast2json bake happens
# at 10.T-2 when the runner exists to consume it.
#
# Usage:
#   bash scripts/import_proposal_corpus.sh --check
#       Verify upstream availability + count .wast per proposal.
#       Exit non-zero if any of the 5 proposals is missing.
#   bash scripts/import_proposal_corpus.sh --copy <proposal>
#       Copy .wast files from upstream into raw/ for one proposal.
#       <proposal> ∈ {memory64, tail-call, exception-handling, gc,
#                     function-references}
#   bash scripts/import_proposal_corpus.sh --copy-all
#       Copy all 5 proposals.
#
# Per Phase 10 design plan §4.6 corpus 取り込み手順.

set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM_ROOT="${WASM_PROPOSAL_ROOT:-$HOME/Documents/OSS/WebAssembly}"
DEST_ROOT="test/spec/wasm-3.0-assert"

# Per design plan §3.1-§3.5 + §4.6:
# - memory64:           test/core/*.wast   (~120 files; base + 64 variants)
# - tail-call:          test/core/*.wast   (~95 files)
# - exception-handling: test/core/*.wast   (~4 core EH wast; rest are base re-export)
# - gc:                 test/core/gc/*.wast (~18 GC-specific; base in test/core/)
# - function-references:test/core/*.wast   (~100 files; GC prereq)
proposal_path() {
    case "$1" in
        memory64)            echo "memory64/test/core" ;;
        tail-call)           echo "tail-call/test/core" ;;
        exception-handling)  echo "exception-handling/test/core" ;;
        gc)                  echo "gc/test/core/gc" ;;
        function-references) echo "function-references/test/core" ;;
        # 10.M cycle 65 — multi-memory proposal lives under the
        # memory64 upstream as a sub-test-core directory; jointly
        # tracked but exposed as its own zwasm corpus proposal.
        multi-memory)        echo "memory64/test/core/multi-memory" ;;
        *) return 1 ;;
    esac
}

PROPOSALS=(memory64 tail-call exception-handling gc function-references multi-memory)

check_one() {
    local p="$1"
    local rel; rel="$(proposal_path "$p")" || { echo "[FAIL] $p: unknown proposal" >&2; return 1; }
    local src="$UPSTREAM_ROOT/$rel"
    if [ ! -d "$src" ]; then
        echo "[FAIL] $p: upstream missing at $src" >&2
        return 1
    fi
    local n; n=$(find "$src" -maxdepth 1 -name '*.wast' | wc -l | tr -d ' ')
    if [ "$n" = 0 ]; then
        echo "[FAIL] $p: no .wast in $src" >&2
        return 1
    fi
    printf "[OK]   %-22s %4s .wast  (%s)\n" "$p" "$n" "$src"
}

copy_one() {
    local p="$1"
    local rel; rel="$(proposal_path "$p")" || { echo "unknown proposal: $p" >&2; return 1; }
    local src="$UPSTREAM_ROOT/$rel"
    local dst="$DEST_ROOT/$p/raw"
    if [ ! -d "$src" ]; then
        echo "[copy] $p: upstream missing at $src" >&2
        return 1
    fi
    mkdir -p "$dst"
    # Use rsync if available (preserves mtime, deletes stale);
    # otherwise plain cp (rsync absent on some host minimal nix
    # shells). Either path is idempotent for the rebuild use case.
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete --include='*.wast' --exclude='*' "$src/" "$dst/"
    else
        rm -rf "$dst"; mkdir -p "$dst"
        find "$src" -maxdepth 1 -name '*.wast' -exec cp {} "$dst/" \;
    fi
    local n; n=$(find "$dst" -maxdepth 1 -name '*.wast' | wc -l | tr -d ' ')
    echo "[copy] $p: $n .wast → $dst"
}

case "${1:-}" in
    --check)
        echo "[import_proposal_corpus] checking ${#PROPOSALS[@]} proposals under $UPSTREAM_ROOT ..."
        rc=0
        for p in "${PROPOSALS[@]}"; do
            check_one "$p" || rc=1
        done
        exit "$rc"
        ;;
    --copy)
        if [ -z "${2:-}" ]; then
            echo "usage: $0 --copy <proposal>" >&2
            exit 2
        fi
        copy_one "$2"
        ;;
    --copy-all)
        rc=0
        for p in "${PROPOSALS[@]}"; do
            copy_one "$p" || rc=1
        done
        exit "$rc"
        ;;
    ""|--help|-h)
        sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "unknown command: $1 (try --check / --copy / --copy-all / --help)" >&2
        exit 2
        ;;
esac
