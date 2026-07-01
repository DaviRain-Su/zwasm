#!/usr/bin/env bash
# Regenerate the curated Wasm 2.0 corpus from the upstream
# WebAssembly/spec testsuite. For each .wast file in NAMES below,
# `wasm-tools json-from-wast` (D-290: one modern CLI) bakes binary
# modules + commands JSON; the script distils the JSON into a flat
# manifest the wast_runner consumes.
#
# Tool-difference handling vs the old wabt wast2json (D-290 methodology):
#   - valid binary modules: `strip --all` drops wasm-tools' default
#     `name` custom section so output stays minimal (matches the wabt
#     baseline; a +2B extended elem-segment encoding remains on a few,
#     both valid + parser-accepted).
#   - valid TEXT modules (`module_type: text`, e.g. comments.wast m[4]):
#     wasm-tools emits a `.wat` where wabt compiled a `.wasm`; convert
#     via `wasm-tools parse` then strip (verified byte-identical to the
#     committed baseline). Manifest name is normalized to `.wasm`.
#   - assert_invalid / assert_malformed BINARY modules: intentionally
#     broken literal bytes — copy RAW (never re-encode/strip).
#
# Phase 2 / §9.2 / 2.8: corpus expansion is iterative — adding a
# .wast file here surfaces validator gaps for the runner to fail
# loudly. Names are curated to keep the gate green; entries land
# only when their .wasms pass.
#
# NOTE: the committed corpus is a SNAPSHOT — there is no recorded
# upstream pin, and upstream has since moved (e.g. func.wast lost
# assert cases), so re-running here produces a large diff that is
# mostly upstream content drift, NOT the wasm-tools swap. A genuine
# corpus refresh (with coverage review of dropped cases) is a
# deliberate, separate act; this script's swap was validated by
# regenerating + `zig build test-spec-wasm-2.0` green (1151 passed),
# then reverting the data.

set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM=${WASM_SPEC_REPO:-$HOME/Documents/OSS/WebAssembly/spec}
DEST=test/spec/wasm-2.0

if ! command -v wasm-tools >/dev/null 2>&1; then
  echo "[regen_test_data_2_0] wasm-tools not found (need it in PATH or dev shell)" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "[regen_test_data_2_0] python3 not found" >&2
  exit 1
fi
if [ ! -d "$UPSTREAM/test/core" ]; then
  echo "[regen_test_data_2_0] upstream not found at $UPSTREAM/test/core" >&2
  echo "[regen_test_data_2_0] set WASM_SPEC_REPO env var to override" >&2
  exit 1
fi

# Curated set: each name corresponds to one .wast file. Add a name
# only when its modules pass / its assert_invalids correctly fail.
NAMES=(
  const
  nop
  unreachable
  br
  return
  call
  labels
  switch
  unwind
  forward
  local_get
  local_set
  stack
  address
  endianness
  int_exprs
  comments
  type
  store
  load
  names
  memory_grow
  traps
  float_exprs
  float_misc
  float_memory
  conversions
  f32
  f32_bitwise
  f32_cmp
  f64
  f64_bitwise
  f64_cmp
  float_literals
  i32
  i64
  inline-module
  int_literals
  left-to-right
  memory_redundancy
  memory_size
  memory_trap
  skip-stack-guard-page
  token
  utf8-invalid-encoding
  obsolete-keywords
  func
  br_if
  local_tee
  table_size
)

for n in "${NAMES[@]}"; do
  src="$UPSTREAM/test/core/$n.wast"
  if [ ! -f "$src" ]; then
    echo "[regen_test_data_2_0] missing $src" >&2
    exit 1
  fi
  TMP=$(mktemp -d)
  trap "rm -rf '$TMP'" EXIT

  # wasm-tools enables all proposals by default (no --enable-* flags).
  ( cd "$TMP" && wasm-tools json-from-wast "$src" -o "$n.json" --wasm-dir . >/dev/null 2>&1 )

  out_dir="$DEST/$n"
  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  python3 - "$TMP/$n.json" "$out_dir/manifest.txt" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
lines = []
for c in d['commands']:
  t = c.get('type')
  if t == 'module':
    fn = c['filename']
    if fn.endswith('.wat'):  # valid text module → normalize to its .wasm name
      fn = fn[:-4] + '.wasm'
    lines.append('valid ' + fn)
  elif t in ('assert_invalid', 'assert_malformed') and c.get('module_type') == 'binary':
    kind = 'invalid' if t == 'assert_invalid' else 'malformed'
    lines.append(kind + ' ' + c['filename'])
with open(dst, 'w') as f:
  f.write('\n'.join(lines) + '\n')
PY

  # Materialize referenced .wasm files per the D-290 tool-difference rules.
  while read -r kind file; do
    [[ "$file" == *.wasm ]] || continue
    base="${file%.wasm}"
    if [[ "$kind" == "valid" ]]; then
      if [[ -f "$TMP/$file" ]]; then
        wasm-tools strip --all "$TMP/$file" -o "$out_dir/$file"
      else  # emitted as a .wat text module — parse then strip
        wasm-tools parse "$TMP/$base.wat" -o "$TMP/$base.fromwat.wasm"
        wasm-tools strip --all "$TMP/$base.fromwat.wasm" -o "$out_dir/$file"
      fi
    else  # invalid / malformed binary: intentionally broken — copy raw
      cp "$TMP/$file" "$out_dir/"
    fi
  done < "$out_dir/manifest.txt"

  rm -rf "$TMP"
  trap - EXIT
done

echo "[regen_test_data_2_0] re-baked: ${NAMES[*]}"
