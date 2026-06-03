#!/usr/bin/env bash
# scripts/bench_aot_coldstart.sh — §12.4 cold-start bench-delta (ADR-0040 / ADR-0140).
#
# Measures AOT load+first-call vs JIT compile+first-call cold start:
#   AOT: `zwasm run prog.cwasm`            (parse .cwasm header → mmap → copy
#                                            code → reloc → first call)
#   JIT: `zwasm run --engine=jit prog.wasm` (parse wasm → lower → regalloc →
#                                            emit → install → first call)
# on COMPUTE (zero-import) fixtures (the SIMD corpus — WASI-importing fixtures
# run on neither path until JIT-WASI/D-251, per ADR-0140). Exit criterion:
# AOT ≥30% faster on ≥3 fixtures.
#
# A verification tool, not a per-commit gate (each fixture is ~1.5s of
# hyperfine). Bench host = Mac + Linux (ADR-0137). Writes a committed report
# to bench/results/aot_coldstart.md.
#
# Usage:  bash scripts/bench_aot_coldstart.sh
#   Exit 0 if ≥3 fixtures clear ≥30%; 1 otherwise.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v hyperfine >/dev/null 2>&1; then
    echo "[bench_aot_coldstart] hyperfine not on PATH (the nix dev shell pins it)." >&2
    exit 1
fi

ZWASM=./zig-out/bin/zwasm
if [ ! -x "$ZWASM" ]; then
    echo "[bench_aot_coldstart] building zwasm exe ..."
    zig build
fi

THRESHOLD_PCT=30
WARMUP=5
RUNS=30
FIXTURES=(i32x4_add f32x4_add i32x4_mul i16x8_mul i8x16_swizzle v128_and)

REPORT=bench/results/aot_coldstart.md
tmp_cwasm=$(mktemp -t aot_cs.XXXXXX).cwasm
tmp_json=$(mktemp -t aot_cs.XXXXXX).json
trap 'rm -f "$tmp_cwasm" "$tmp_json"' EXIT

passed=0
total=0
rows=""
for f in "${FIXTURES[@]}"; do
    wasm="bench/runners/wasm/simd/${f}.wasm"
    [ -f "$wasm" ] || { echo "[bench_aot_coldstart] missing fixture: $wasm" >&2; continue; }
    total=$((total + 1))
    "$ZWASM" compile "$wasm" -o "$tmp_cwasm" 2>/dev/null

    hyperfine --warmup "$WARMUP" --runs "$RUNS" -N --export-json "$tmp_json" \
        "$ZWASM run $tmp_cwasm" \
        "$ZWASM run --engine=jit $wasm" >/dev/null 2>&1

    # results[0] = AOT, results[1] = JIT. delta% = (jit - aot)/jit * 100.
    read -r aot_ms jit_ms delta_pct <<<"$(python3 - "$tmp_json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))["results"]
aot, jit = r[0]["mean"] * 1000, r[1]["mean"] * 1000
print(f"{aot:.2f} {jit:.2f} {(jit-aot)/jit*100:.1f}")
PY
)"
    mark="FAIL"
    if (( $(echo "$delta_pct >= $THRESHOLD_PCT" | bc -l) )); then
        mark="ok"
        passed=$((passed + 1))
    fi
    printf '  %-16s AOT %6s ms  JIT %6s ms  delta %5s%%  [%s]\n' "$f" "$aot_ms" "$jit_ms" "$delta_pct" "$mark"
    rows="${rows}| \`${f}\` | ${aot_ms} | ${jit_ms} | ${delta_pct}% | ${mark} |"$'\n'
done

{
    echo "# AOT cold-start bench-delta (§12.4 / ADR-0040)"
    echo
    echo "Host: \`$(uname -sm)\` (bench 2-host Mac+Linux per ADR-0137; numbers are point-in-time, machine-specific)."
    echo
    echo "AOT \`zwasm run *.cwasm\` (load+reloc+first-call) vs JIT \`zwasm run --engine=jit *.wasm\`"
    echo "(parse+lower+regalloc+emit+first-call), compute (zero-import) SIMD fixtures."
    echo "Threshold: AOT ≥${THRESHOLD_PCT}% faster on ≥3 fixtures (warmup ${WARMUP}, runs ${RUNS})."
    echo
    echo "| fixture | AOT ms | JIT ms | delta | |"
    echo "|---|--:|--:|--:|:-:|"
    printf '%s' "$rows"
    echo
    echo "Result: ${passed}/${total} fixtures cleared ≥${THRESHOLD_PCT}%."
} > "$REPORT"

echo "[bench_aot_coldstart] ${passed}/${total} fixtures cleared ≥${THRESHOLD_PCT}% → report: $REPORT"
if [ "$passed" -ge 3 ]; then
    echo "[bench_aot_coldstart] OK — §12.4 cold-start ≥30% on ${passed} fixtures."
    exit 0
fi
echo "[bench_aot_coldstart] FAIL — fewer than 3 fixtures cleared the threshold." >&2
exit 1
