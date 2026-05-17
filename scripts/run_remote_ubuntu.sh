#!/usr/bin/env bash
# scripts/run_remote_ubuntu.sh — drive build/test on the
# ubuntunote SSH host (native x86_64 Linux, real hardware).
#
# Replacement for the OrbStack `my-ubuntu-amd64` path (Rosetta-
# translated x86_64; tripped D-134 SIGSEGV race). Mirrors
# `run_remote_windows.sh`: `git fetch + reset --hard` the
# ubuntunote clone to the latest pushed `origin/zwasm-from-scratch`,
# then run the requested `zig build` step.
#
# Usage:
#   bash scripts/run_remote_ubuntu.sh                  # default: zig build test-all
#   bash scripts/run_remote_ubuntu.sh build            # zig build
#   bash scripts/run_remote_ubuntu.sh test             # zig build test
#   bash scripts/run_remote_ubuntu.sh test-spec        # zig build test-spec
#
# Prerequisites: SSH alias `ubuntunote` configured; Zig 0.16.0
# available remotely (via `nix develop` from the project's
# flake.nix); the repo cloned at
# ~/Documents/MyProducts/zwasm_from_scratch with `origin`
# pointing at clojurewasm/zwasm and the `zwasm-from-scratch`
# branch checked out. Setup procedure in
# `.dev/ubuntunote_setup.md`.

set -euo pipefail
cd "$(dirname "$0")/.."

STEP="${1:-test-all}"
REMOTE_DIR="Documents/MyProducts/zwasm_from_scratch"
REMOTE_BRANCH="zwasm-from-scratch"

echo "[run_remote_ubuntu] sync ubuntunote:~/$REMOTE_DIR to origin/$REMOTE_BRANCH ..."
ssh ubuntunote "cd $REMOTE_DIR && git fetch origin $REMOTE_BRANCH && git checkout $REMOTE_BRANCH && git reset --hard origin/$REMOTE_BRANCH"

# `build` is the implicit (default) step in build.zig — invoking
# `zig build build` errors. Map the human-friendly arg to no step.
if [ "$STEP" = "build" ]; then
    REMOTE_CMD="zig build"
else
    REMOTE_CMD="zig build $STEP"
fi

# Wrap with `nix develop --command` so Zig 0.16.0 + project deps
# resolve via the pinned flake regardless of remote shell state.
# (Mirror of the Mac-host pattern: `flake.nix` is the single
# source of truth for the toolchain.)
echo "[run_remote_ubuntu] $REMOTE_CMD ..."
ssh ubuntunote "cd $REMOTE_DIR && nix develop --command bash -c '$REMOTE_CMD'"

echo "[run_remote_ubuntu] OK."
