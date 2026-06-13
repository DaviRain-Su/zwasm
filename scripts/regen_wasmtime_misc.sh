#!/usr/bin/env bash
# Regenerate the wasmtime misc_testsuite curated corpus
# (BATCH1 basic + BATCH2 reftypes + BATCH3 embenchen + issues)
# under test/wasmtime_misc/wast/<category>/<fixture>/.
#
# Phase 6 / §9.6 / 6.C per ADR-0012. Each .wast is distilled (D-290
# tool swap: wabt wast2json → `wasm-tools json-from-wast`) into a
# per-fixture subdir; the manifest.txt distils to the
# valid/invalid/malformed directives the wast_runner consumes
# (parse + validate gate). manifest_runtime.txt drives the runtime-
# asserting runner (6.D).
#
# D-290 tool-difference rules (same as regen_spec_2_0_assert.sh):
#   - wasm-tools emits i32/i64 values SIGNED (sometimes as JSON
#     numbers); fold to the unsigned decimals the runner expects.
#   - some valid text modules come out as `.wat`; `wasm-tools parse`
#     them to .wasm.
#   - valid modules carry a `name` custom section; `strip --all`
#     recovers wabt byte-parity. invalid/malformed copy RAW.
#
# Usage:
#   bash scripts/regen_wasmtime_misc.sh
#
# Environment:
#   WASMTIME_REPO   — path to a wasmtime checkout. Defaults to
#                     $HOME/Documents/OSS/wasmtime. ADR-0012 §1
#                     authorises sparse-checkout to .cache/ for
#                     CI; this script just reads from any clone.

set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM=${WASMTIME_REPO:-$HOME/Documents/OSS/wasmtime}
DEST=test/wasmtime_misc/wast

if ! command -v wasm-tools >/dev/null 2>&1; then
  echo "[regen_wasmtime_misc] wasm-tools not found (need it in PATH or dev shell)" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "[regen_wasmtime_misc] python3 not found" >&2
  exit 1
fi
if [ ! -d "$UPSTREAM/tests/misc_testsuite" ]; then
  echo "[regen_wasmtime_misc] upstream not found at $UPSTREAM/tests/misc_testsuite" >&2
  echo "[regen_wasmtime_misc] set WASMTIME_REPO env var to override" >&2
  exit 1
fi

# Per ADR-0013 §2 + ADR-0012 §6.C. The classification mirrors v1
# convert.py's BATCH1-3 (basic ops / reference types / embenchen
# + issue-regression). BATCH4 (SIMD) and BATCH5 (proposals) defer
# per ADR-0012 §6.2.
BATCH1_BASIC=(
  add div-rem mul16-negative
  control-flow simple-unreachable
  misc_traps stack_overflow
  memory-copy imported-memory-copy partial-init-memory-segment
  call_indirect many-results many-return-values
  export-large-signature func-400-params table_copy
  table_copy_on_imported_tables elem-ref-null
  table_grow_with_funcref linking-errors empty
  # Queued for §9.6 / 6.E (v2 validator/interp gaps surfaced):
  #   wide-arithmetic, br-table-fuzzbug, no-panic, no-panic-on-invalid,
  #   elem_drop
)

BATCH2_REFTYPES=(
  f64-copysign float-round-doesnt-load-too-much
  sink-float-but-dont-trap externref-segment
  bit-and-conditions no-opt-panic-dividing-by-zero
  partial-init-table-segment rs2wasm-add-func
  # Queued for §9.6 / 6.E (v2 validator gaps — externref / GC):
  #   int-to-float-splat, externref-id-function,
  #   mutable_externref_globals, simple_ref_is_null,
  #   externref-table-dropped-segment-issue-8281,
  #   many_table_gets_lead_to_gc, no-mixup-stack-maps
)

BATCH3_EMBENCHEN=(
  embenchen_fannkuch embenchen_fasta embenchen_ifs
  embenchen_primes rust_fannkuch fib
)

BATCH3_ISSUES=(
  issue1809 issue4840 issue4857 issue4890
  issue694 issue11748 issue12318
  # Queued for §9.6 / 6.E:
  #   issue6562
)

skipped=()
landed=()

vendor_one() {
  local cat="$1" name="$2"
  local src="$UPSTREAM/tests/misc_testsuite/$name.wast"
  if [ ! -f "$src" ]; then
    skipped+=("$cat/$name (upstream missing)")
    return
  fi
  local out_dir="$DEST/$cat/$name"
  local TMP
  TMP=$(mktemp -d)

  # D-290: wasm-tools enables all proposals by default (no
  # --enable-* flags; the wabt flag set drops).
  if ! ( cd "$TMP" && wasm-tools json-from-wast "$src" -o "$name.json" --wasm-dir . >/dev/null 2>&1 ); then
    skipped+=("$cat/$name (json-from-wast failed)")
    rm -rf "$TMP"
    return
  fi

  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  python3 - "$TMP/$name.json" "$out_dir/manifest.txt" "$out_dir/manifest_runtime.txt" <<'PY'
import json, sys
src, dst_parse, dst_rt = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(src))
parse_lines = []
rt_lines = []

def encode_value(v):
  ty = v.get('type', '')
  raw = v.get('value', '')
  # Values are bit-pattern decimals (ints: the value; floats: the
  # IEEE 754 bit pattern). D-290 baker normalization: wabt emitted
  # them UNSIGNED as strings; wasm-tools emits SIGNED, sometimes as
  # JSON numbers — fold negatives into the unsigned width. Wrap in
  # TLV per ADR-0013 §2 syntax.
  if ty == 'i32':
    try:
      return f'i32:{int(raw) & 0xffffffff}'
    except Exception:
      return None
  if ty == 'i64':
    try:
      return f'i64:{int(raw) & 0xffffffffffffffff}'
    except Exception:
      return None
  if ty == 'f32':
    # bit pattern → emit hex form the runner's parseValue accepts
    # via the `f32:0xHEX` path.
    try:
      return f'f32:0x{int(raw) & 0xffffffff:08x}'
    except Exception:
      return None
  if ty == 'f64':
    try:
      return f'f64:0x{int(raw) & 0xffffffffffffffff:016x}'
    except Exception:
      return None
  # v128 / externref / funcref / null refs deferred — runtime
  # runner doesn't compare those yet. Returning None causes the
  # entire directive to be skipped from manifest_runtime.txt.
  return None

def norm_wasm(fn):
  # wasm-tools emits some valid TEXT modules as `.wat` where wabt
  # compiled `.wasm`; the copy loop converts via `wasm-tools parse`,
  # so normalize the manifest name to its `.wasm` form here.
  return fn[:-4] + '.wasm' if fn.endswith('.wat') else fn

def encode_args(values):
  out = []
  for v in values or []:
    e = encode_value(v)
    if e is None:
      return None
    out.append(e)
  return out

def quote_field(field):
  # The runtime runner tokenises directives by whitespace, so any
  # export name carrying a space (`is hello?`, etc.) must be wrapped
  # in double quotes. Embedded double quotes are escaped with a
  # backslash; the runner's token reader unescapes them.
  if any(c in field for c in ' \t"'):
    return '"' + field.replace('\\', '\\\\').replace('"', '\\"') + '"'
  return field

for c in d['commands']:
  t = c.get('type')
  if t == 'module':
    fn = norm_wasm(c['filename'])
    parse_lines.append('valid ' + fn)
    line = 'module ' + fn
    name = c.get('name')
    if name:
      # wast2json emits a `$id` for `(module $id ...)`; preserve it
      # so a later `register` directive that references the module
      # by id resolves cleanly.
      line += ' as ' + quote_field(str(name))
    rt_lines.append(line)
  elif t == 'register':
    as_name = c.get('as', '')
    line = 'register ' + quote_field(as_name)
    name = c.get('name')
    if name:
      line += ' from ' + quote_field(str(name))
    rt_lines.append(line)
  elif t in ('assert_invalid', 'assert_malformed') and c.get('module_type') == 'binary':
    kind = 'invalid' if t == 'assert_invalid' else 'malformed'
    parse_lines.append(kind + ' ' + c['filename'])
  elif t in ('assert_unlinkable', 'assert_uninstantiable') and c.get('module_type') == 'binary':
    rt_lines.append(t + ' ' + c['filename'])
  elif t == 'assert_return':
    act = c.get('action', {})
    if act.get('type') != 'invoke':
      continue
    args = encode_args(act.get('args'))
    expected = encode_args(c.get('expected'))
    if args is None or expected is None:
      continue
    field = act.get('field', '')
    rt_line = 'assert_return ' + quote_field(field)
    if args:
      rt_line += ' ' + ' '.join(args)
    rt_line += ' -> ' + (' '.join(expected) if expected else '')
    rt_lines.append(rt_line.rstrip())
  elif t == 'action':
    # Bare `(invoke <field> <args>)` action lines mutate state
    # between asserts (memory.copy / table.copy etc.). Emit
    # them as `invoke <field> <args>` so the runtime runner
    # actually executes them; without this the asserts that
    # follow check stale memory/table state.
    act = c.get('action', {})
    if act.get('type') != 'invoke':
      continue
    args = encode_args(act.get('args'))
    if args is None:
      continue
    field = quote_field(act.get('field', ''))
    rt_line = 'invoke ' + field
    if args:
      rt_line += ' ' + ' '.join(args)
    rt_lines.append(rt_line.rstrip())
  elif t == 'assert_trap':
    act = c.get('action', {})
    if act.get('type') != 'invoke':
      continue
    args = encode_args(act.get('args'))
    if args is None:
      continue
    field = quote_field(act.get('field', ''))
    # Map wast2json's spec-text trap message to the v2 c_api
    # TrapKind tag the runner expects. Names are the v2-side
    # tag names (see test/runners/wast_runtime_runner.zig
    # trapKindName).
    spec_text = c.get('text', '')
    tag_map = {
      'unreachable': 'Unreachable',
      'integer divide by zero': 'DivByZero',
      'divide by zero': 'DivByZero',
      'integer overflow': 'IntOverflow',
      'invalid conversion to integer': 'InvalidConversionToInt',
      'out of bounds memory access': 'OutOfBounds',
      'out of bounds': 'OutOfBounds',
      'out of bounds table access': 'OutOfBoundsTableAccess',
      'uninitialized element': 'UninitializedElement',
      'indirect call type mismatch': 'IndirectCallTypeMismatch',
      'call stack exhausted': 'StackOverflow',
      # `undefined element` is the wast-spec name for table-OOB
      # accesses on bulk operations (table.copy / table.init).
      # `uninitialized element` is the call_indirect-on-null trap.
      # The two share wording in older wast files but map to
      # distinct v2 TrapKinds.
      'undefined element': 'OutOfBoundsTableAccess',
    }
    kind = tag_map.get(spec_text, 'Unreachable')
    rt_line = 'assert_trap ' + field
    if args:
      rt_line += ' ' + ' '.join(args)
    rt_line += ' !! ' + kind
    rt_lines.append(rt_line)

with open(dst_parse, 'w') as f:
  f.write('\n'.join(parse_lines) + '\n')
with open(dst_rt, 'w') as f:
  f.write('\n'.join(rt_lines) + '\n')
PY

  if [ ! -s "$out_dir/manifest.txt" ]; then
    rm -rf "$out_dir"
    skipped+=("$cat/$name (no parse/validate-only directives)")
    rm -rf "$TMP"
    return
  fi

  # Materialize referenced .wasm files (D-290 tool-difference rules):
  #   - valid / module / assert_uninstantiable / assert_unlinkable:
  #     valid binaries — strip wasm-tools' name section; a `.wat`
  #     text-module emission is parsed to .wasm first.
  #   - invalid / malformed: intentionally broken — copy RAW (never
  #     re-encode/strip). Walk both manifests so .wasm files
  #     referenced only by manifest_runtime.txt also land.
  while read -r d1 file _; do
    [ -f "$out_dir/$file" ] && continue
    case "$d1" in
      valid)
        base="${file%.wasm}"
        if [ -f "$TMP/$file" ]; then
          wasm-tools strip --all "$TMP/$file" -o "$out_dir/$file"
        elif [ -f "$TMP/$base.wat" ]; then
          wasm-tools parse "$TMP/$base.wat" -o "$TMP/$base.fromwat.wasm"
          wasm-tools strip --all "$TMP/$base.fromwat.wasm" -o "$out_dir/$file"
        fi
        ;;
      invalid|malformed)
        if [ -f "$TMP/$file" ]; then
          cp "$TMP/$file" "$out_dir/"
        fi
        ;;
    esac
  done < "$out_dir/manifest.txt"
  if [ -f "$out_dir/manifest_runtime.txt" ]; then
    while read -r d1 file _; do
      case "$d1" in
        module|assert_uninstantiable|assert_unlinkable)
          [ -f "$out_dir/$file" ] && continue
          base="${file%.wasm}"
          if [ -f "$TMP/$file" ]; then
            wasm-tools strip --all "$TMP/$file" -o "$out_dir/$file"
          elif [ -f "$TMP/$base.wat" ]; then
            wasm-tools parse "$TMP/$base.wat" -o "$TMP/$base.fromwat.wasm"
            wasm-tools strip --all "$TMP/$base.fromwat.wasm" -o "$out_dir/$file"
          fi
          ;;
      esac
    done < "$out_dir/manifest_runtime.txt"
  fi

  # Curation: embenchen `.1.wasm` modules are emcc guests importing
  # env.* glue that no directive registers/provides — keep the
  # committed skip (token validated by check_skip_adrs.sh) instead
  # of letting them fail instantiation.
  if [ "$cat" = embenchen ] && [ -f "$out_dir/manifest_runtime.txt" ]; then
    python3 - "$out_dir/manifest_runtime.txt" <<'PY'
import re, sys
p = sys.argv[1]
lines = open(p).read().splitlines()
out = [re.sub(r'^module (\S+\.1\.wasm)$',
              r'skip-adr-skip_embenchen_emcc_env_imports \1', l)
       for l in lines]
open(p, 'w').write('\n'.join(out) + '\n')
PY
  fi

  landed+=("$cat/$name")
  rm -rf "$TMP"
}

for n in "${BATCH1_BASIC[@]}";    do vendor_one basic    "$n"; done
for n in "${BATCH2_REFTYPES[@]}"; do vendor_one reftypes "$n"; done
for n in "${BATCH3_EMBENCHEN[@]}"; do vendor_one embenchen "$n"; done
for n in "${BATCH3_ISSUES[@]}";   do vendor_one issues   "$n"; done

echo "[regen_wasmtime_misc] landed: ${#landed[@]}"
for x in "${landed[@]}"; do echo "  $x"; done
echo "[regen_wasmtime_misc] skipped: ${#skipped[@]}"
for x in "${skipped[@]}"; do echo "  $x"; done
