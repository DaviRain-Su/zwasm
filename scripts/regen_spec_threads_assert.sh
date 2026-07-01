#!/usr/bin/env bash
# scripts/regen_spec_threads_assert.sh — Threads/atomics official spec corpus.
#
# Distils the upstream testsuite `proposals/threads/atomic.wast` into the
# scalar manifest format consumed by `spec_assert_runner_non_simd` (the host
# runner per the atomics-spec-corpus bundle — broad arg-taking scalar
# execution; the wasm_3_0 runner skips arg-taking asserts).
#
# atomics ops are pure-integer scalar (i32/i64), so NO `(either)` / v128 / nan
# complications. The non_simd runner PERSISTS linear memory across directives
# within a module, so the `action` (store/init) commands are emitted as
# void-result invokes (`-> ()`) to set up state for the load/rmw asserts.
#
# Source: TESTSUITE (proposals/threads), NOT spec/test/core. Run on Mac in the
# nix dev shell (`nix develop .#gen` or with wabt + python3 on PATH).

set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM=${WASM_TESTSUITE_REPO:-$HOME/Documents/OSS/WebAssembly/testsuite}
DEST=test/spec/threads-assert
SRC="$UPSTREAM/proposals/threads/atomic.wast"

if ! command -v wasm-tools >/dev/null 2>&1; then
  echo "[regen_spec_threads_assert] wasm-tools not found (need it / nix dev shell)" >&2
  exit 1
fi
if [ ! -f "$SRC" ]; then
  echo "[regen_spec_threads_assert] missing $SRC" >&2
  exit 1
fi

n=atomic
TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT

# D-290: wasm-tools enables all proposals by default (the wabt --enable-threads
# flag drops).
if ! ( cd "$TMP" && wasm-tools json-from-wast "$SRC" -o "$n.json" --wasm-dir . >/dev/null 2>&1 ); then
  echo "[regen_spec_threads_assert] json-from-wast rejected $SRC" >&2
  exit 1
fi

out_dir="$DEST/$n"
rm -rf "$out_dir"
mkdir -p "$out_dir"

python3 - "$TMP/$n.json" "$out_dir/manifest.txt" <<'PY'
import json, sys

src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))

SCALARS = ("i32", "i64", "f32", "f64")

def norm_wasm(fn):
    return fn[:-4] + ".wasm" if fn.endswith(".wat") else fn

def tok(v):
    """`<type>:<value>` for a scalar arg/result; `!` prefix = unsupported.
    D-290 baker normalization: wasm-tools emits i32/i64 SIGNED; the runner +
    committed baseline use unsigned decimals — fold negatives to the width."""
    t = v["type"]
    if t in SCALARS:
        val = v["value"]
        if t in ("i32", "i64"):
            try:
                nn = int(val)
                if nn < 0:
                    nn += (1 << 32) if t == "i32" else (1 << 64)
                val = str(nn)
            except (TypeError, ValueError):
                pass
        return f"{t}:{val}"
    return f"!unsupported-type:{t}"

def toks(items):
    out = [tok(x) for x in items]
    bad = [x for x in out if x.startswith("!")]
    return (None, bad[0]) if bad else (" ".join(out) if out else "()", None)

lines = []
for c in d["commands"]:
    t = c.get("type")
    if t == "module":
        lines.append("module " + norm_wasm(c["filename"]))
    elif t in ("assert_return", "action"):
        # Both nest the invoke under `.action`; `action` commands have
        # `expected:[]` (void invoke run for its side effect — store/init).
        # The runner persists memory across directives, so these set up state
        # for later load/rmw asserts.
        act = c["action"]
        if act.get("type") != "invoke":
            lines.append("skip-impl non-invoke-action")
            continue
        # memory.atomic.wait{32,64} run on the atomics corpus's `(memory 1 1 shared)`
        # modules: the runner now seeds `current_mem_shared` from the module
        # (base.extractMemory0Shared → makeJitRuntime.mem0_shared), so wait does NOT
        # trap kind=15. zwasm's wait is non-blocking (single-thread → 1=not-equal /
        # 2=timed-out immediately), so no hang. Emit the real assert_return.
        args_s, bad = toks(act.get("args", []))
        res_s, bad2 = toks(c.get("expected", []))
        if bad or bad2:
            lines.append(f"skip-impl bad-token {act['field']} {bad or bad2}")
            continue
        fn = act["field"]
        fn_tok = f"'{fn}'" if " " in fn else fn
        lines.append(f"assert_return {fn_tok} {args_s} -> {res_s}")
    elif t == "assert_trap":
        # Atomic unaligned-access traps. nonSimdRunAssertTrap's dispatch ladder
        # covers every atomics trap shape (1-arg load, 2-arg store/rmw, 3-arg
        # i32/i64 cmpxchg) as of §17.4 D-301; the JIT now traps on unaligned ea
        # for load/store too (D-303 fix: unaligned_atomic_fixups stub, both
        # arches) as well as RMW/cmpxchg/wait/notify (jit_abi helper), so emit
        # the real directive — Error.Trap is the only PASS.
        a = c["action"]
        if a.get("type") != "invoke":
            lines.append("skip-impl non-invoke-action-trap")
            continue
        fn = a.get("field", "?")
        args_s, bad = toks(a.get("args", []))
        if bad:
            lines.append(f"skip-impl bad-token {fn} {bad}")
            continue
        fn_tok = f"'{fn}'" if " " in fn else fn
        lines.append(f"assert_trap {fn_tok} {args_s}")
    elif t == "assert_invalid":
        lines.append(f"assert_invalid {c['filename']}")
    elif t == "assert_malformed":
        if c.get("module_type") == "binary" and "filename" in c:
            lines.append(f"assert_malformed {c['filename']}")
        else:
            lines.append("skip-adr-skip_text_format_parser directive-assert_malformed-text")
    else:
        lines.append(f"skip-impl directive-{t}")

open(dst, "w").write("\n".join(lines) + "\n")
PY

# Materialize referenced .wasm files (D-290 tool-difference rules): valid
# `module` → strip wasm-tools' name section (+ .wat→parse); invalid/malformed
# copy RAW (intentionally broken).
while read -r line; do
  set -- $line
  case "$1" in
    module)
      base="${2%.wasm}"
      if [ -f "$TMP/$2" ]; then
        wasm-tools strip --all "$TMP/$2" -o "$out_dir/$2"
      elif [ -f "$TMP/$base.wat" ]; then
        wasm-tools parse "$TMP/$base.wat" -o "$TMP/$base.fromwat.wasm"
        wasm-tools strip --all "$TMP/$base.fromwat.wasm" -o "$out_dir/$2"
      fi
      ;;
    assert_invalid|assert_malformed)
      [ -f "$TMP/$2" ] && cp "$TMP/$2" "$out_dir/"
      ;;
  esac
done < "$out_dir/manifest.txt"

echo "[regen_spec_threads_assert] re-baked: $n → $DEST/"
