#!/usr/bin/env bash
# §11.3 SIMD per-op gap analysis (D-074 / 11.3-simd-gap bundle).
#
# Reads a multi-runtime recent.yaml — `simd/*` op rows for zwasm (JIT),
# wasmtime, wazero, wasmer, produced by:
#   nix develop --command bash scripts/run_bench.sh --simd --quick --compare=all
# and reports, per op, the ratio  zwasm_mean / median(comparators) , sorted
# worst-gap first, flagging ops where zwasm's JIT lags the comparator median
# by more than THRESHOLD (default 3x). Flagged ops + their candidate
# optimisation seed the Phase-15 SIMD-perf debt entries (§9.10 Track A:
# AVX/CPUID path, MOVAPS preamble peephole, SIMD-specific coalescing).
#
# Output: a markdown table on stdout (redirect to a profile doc).
set -euo pipefail
cd "$(dirname "$0")/.."

RECENT="${1:-bench/results/recent.yaml}"
THRESHOLD="${2:-3.0}"
if [ ! -f "$RECENT" ]; then
    echo "[simd_gap] missing $RECENT — run: nix develop --command bash scripts/run_bench.sh --simd --quick --compare=all" >&2
    exit 1
fi

# name<TAB>runtime<TAB>mean_ms for simd/* ops in the most-recent run entry.
data=$(yq -r '.[-1].benches[] | select(.name | test("^simd/")) | [.name, .runtime, .mean_ms] | @tsv' "$RECENT")
if [ -z "$data" ]; then
    echo "[simd_gap] no simd/* rows in $RECENT (did the --simd run land?)" >&2
    exit 1
fi

rows=$(printf '%s\n' "$data" | awk -v th="$THRESHOLD" '
  BEGIN { FS = "\t" }
  { m[$1"|"$2] = $3; if (!($1 in seen)) { seen[$1] = 1 } }
  END {
    for (op in seen) {
      z = m[op"|zwasm"]; wt = m[op"|wasmtime"]; wz = m[op"|wazero"]; ws = m[op"|wasmer"]
      c = 0
      if (wt != "") a[c++] = wt
      if (wz != "") a[c++] = wz
      if (ws != "") a[c++] = ws
      for (i = 0; i < c; i++) for (j = i+1; j < c; j++) if (a[j] < a[i]) { t = a[i]; a[i] = a[j]; a[j] = t }
      if (c == 0) med = 0
      else if (c % 2 == 1) med = a[int(c/2)]
      else med = (a[c/2 - 1] + a[c/2]) / 2
      ratio = (med > 0) ? z / med : 0
      flag = (ratio > th) ? "**YES**" : ""
      printf "%.6f\t| %s | %.3f | %s | %s | %s | %.3f | %.2fx | %s |\n", \
             ratio, op, z, (wt==""?"-":wt), (wz==""?"-":wz), (ws==""?"-":ws), med, ratio, flag
      delete a
    }
  }' | sort -t"$(printf '\t')" -k1 -rn | cut -f2-)

flagged=$(printf '%s\n' "$rows" | grep -c '\*\*YES\*\*' || true)
total=$(printf '%s\n' "$rows" | grep -c '^|' || true)

echo "# §11.3 SIMD per-op gap — zwasm JIT vs median(wasmtime, wazero, wasmer)"
echo ""
echo "Source: \`$RECENT\` · threshold: ${THRESHOLD}x · $(yq -r '.[-1].arch' "$RECENT") · $(yq -r '.[-1].commit' "$RECENT" | cut -c1-12)"
echo ""
echo "| op | zwasm_ms | wasmtime | wazero | wasmer | median | zwasm/median | >${THRESHOLD}x |"
echo "|----|---------:|---------:|-------:|-------:|-------:|-------------:|:------:|"
printf '%s\n' "$rows"
echo ""
echo "${total} ops analysed; ${flagged} lag the comparator median by > ${THRESHOLD}x."
