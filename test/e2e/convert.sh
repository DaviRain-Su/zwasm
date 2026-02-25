#!/bin/bash
# Copy + convert wasmtime misc_testsuite .wast files for zwasm e2e testing.
#
# Usage: bash test/e2e/convert.sh [--batch N]
#   --batch 1  Priority 1: Core MVP & Traps (~25 files)
#   --batch 2  Priority 2: Float & Reference Types (~15 files)
#   --batch 3  Priority 3: Programs & Regressions (~20 files)
#   --batch 4  Priority 4: SIMD (~15 files)
#   --batch 5  Priority 5: Proposals (GC, Threads, Memory64, etc.)
#   (no flag)  All portable files

set -e
cd "$(dirname "$0")/../.."

WASMTIME_MISC="${WASMTIME_MISC_DIR:-$HOME/Documents/OSS/wasmtime/tests/misc_testsuite}"
WAST_DIR="test/e2e/wast"
JSON_DIR="test/e2e/json"
SKIP_FILE="test/e2e/skip.txt"

if [ ! -d "$WASMTIME_MISC" ]; then
    echo "ERROR: wasmtime misc_testsuite not found at $WASMTIME_MISC"
    exit 1
fi

mkdir -p "$WAST_DIR" "$JSON_DIR"

# Build skip patterns from skip.txt
SKIP_DIRS=()
SKIP_FILES=()
while IFS= read -r line; do
    line="${line%%#*}"        # strip comments
    line="${line%"${line##*[! ]}"}"  # strip trailing spaces
    [ -z "$line" ] && continue
    if [[ "$line" == */ ]]; then
        SKIP_DIRS+=("$line")
    else
        SKIP_FILES+=("$line")
    fi
done < "$SKIP_FILE"

is_skipped() {
    local file="$1"
    local name
    name=$(basename "$file")
    local relpath="${file#$WASMTIME_MISC/}"

    # Check directory skips
    for dir in "${SKIP_DIRS[@]}"; do
        if [[ "$relpath" == "$dir"* ]]; then
            return 0
        fi
    done

    # Check file skips
    for skip in "${SKIP_FILES[@]}"; do
        if [[ "$name" == "$skip" ]]; then
            return 0
        fi
    done

    return 1
}

# Batch file lists
BATCH1=(
    add.wast div-rem.wast mul16-negative.wast wide-arithmetic.wast
    control-flow.wast br-table-fuzzbug.wast simple-unreachable.wast
    misc_traps.wast stack_overflow.wast no-panic.wast no-panic-on-invalid.wast
    memory-copy.wast imported-memory-copy.wast
    partial-init-memory-segment.wast
    call_indirect.wast many-results.wast many-return-values.wast
    export-large-signature.wast func-400-params.wast
    table_copy.wast table_copy_on_imported_tables.wast
    elem_drop.wast elem-ref-null.wast table_grow_with_funcref.wast
    linking-errors.wast empty.wast
)

BATCH2=(
    f64-copysign.wast float-round-doesnt-load-too-much.wast
    int-to-float-splat.wast sink-float-but-dont-trap.wast
    externref-id-function.wast externref-segment.wast
    mutable_externref_globals.wast simple_ref_is_null.wast
    externref-table-dropped-segment-issue-8281.wast
    bit-and-conditions.wast no-opt-panic-dividing-by-zero.wast
    partial-init-table-segment.wast
    many_table_gets_lead_to_gc.wast
    no-mixup-stack-maps.wast rs2wasm-add-func.wast
)

BATCH3=(
    embenchen_fannkuch.wast embenchen_fasta.wast
    embenchen_ifs.wast embenchen_primes.wast
    rust_fannkuch.wast fib.wast
    issue1809.wast issue4840.wast issue4857.wast issue4890.wast
    issue6562.wast issue694.wast
    issue11748.wast issue12318.wast
)

# .wat files need special handling (none currently — issue11563.wat needs GC, issue12170.wat has no assertions)
BATCH3_WAT=()

BATCH4_SIMD=(
    simd/cvt-from-uint.wast
    simd/edge-of-memory.wast simd/unaligned-load.wast
    simd/load_splat_out_of_bounds.wast simd/v128-select.wast
    simd/replace-lane-preserve.wast simd/almost-extmul.wast
    simd/interesting-float-splat.wast
    simd/issue4807.wast simd/issue6725-no-egraph-panic.wast
    simd/issue_3173_select_v128.wast simd/issue_3327_bnot_lowering.wast
    simd/spillslot-size-fuzzbug.wast simd/sse-cannot-fold-unaligned-loads.wast
)

# Batch 5: Proposal-specific E2E tests
BATCH5_PROPOSALS=(
    # Function references (instance.wast excluded: uses module_definition/module_instance)
    function-references/call_indirect.wast
    function-references/table_fill.wast
    function-references/table_get.wast
    function-references/table_grow.wast
    function-references/table_set.wast
    # Tail call
    tail-call/loop-across-modules.wast
    # Multi-memory
    multi-memory/simple.wast
    # Threads
    threads/LB.wast threads/LB_atomic.wast
    threads/MP.wast threads/MP_atomic.wast threads/MP_wait.wast
    threads/SB.wast threads/SB_atomic.wast
    threads/atomics-end-of-memory.wast threads/atomics_notify.wast
    threads/atomics_wait_address.wast threads/load-store-alignment.wast
    threads/wait_notify.wast
    # Memory64 (more-than-4gb excluded: needs >4GB RAM)
    memory64/bounds.wast memory64/codegen.wast
    memory64/linking-errors.wast memory64/linking.wast
    memory64/multi-memory.wast memory64/offsets.wast
    memory64/simd.wast memory64/threads.wast
    # GC
    gc/alloc-v128-struct.wast gc/anyref_that_is_i31_barriers.wast
    gc/array-alloc-too-large.wast gc/array-init-data.wast
    gc/array-new-data.wast gc/array-new-elem.wast
    gc/array-types.wast gc/arrays-of-different-types.wast
    gc/externrefs-can-be-i31refs.wast gc/func-refs-in-gc-heap.wast
    gc/fuzz-segfault.wast gc/i31ref-of-global-initializers.wast
    gc/i31ref-tables.wast gc/issue-10171.wast gc/issue-10182.wast
    gc/issue-10353.wast gc/issue-10397.wast gc/issue-10459.wast
    gc/issue-10467.wast gc/more-rec-groups-than-types.wast
    gc/null-i31ref.wast gc/rec-group-funcs.wast gc/ref-test.wast
    gc/struct-instructions.wast gc/struct-types.wast
)

# Determine which files to process
BATCH="${1#--batch=}"
[ "$1" = "--batch" ] && BATCH="$2"

collect_files() {
    local files=()
    case "$BATCH" in
        1)
            for f in "${BATCH1[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            ;;
        2)
            for f in "${BATCH2[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            ;;
        3)
            for f in "${BATCH3[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            for f in "${BATCH3_WAT[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            ;;
        4)
            for f in "${BATCH4_SIMD[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            ;;
        5)
            for f in "${BATCH5_PROPOSALS[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            ;;
        *)
            # All batches combined (explicit list — no wildcard scan)
            for f in "${BATCH1[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            for f in "${BATCH2[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            for f in "${BATCH3[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            for f in "${BATCH3_WAT[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            for f in "${BATCH4_SIMD[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            for f in "${BATCH5_PROPOSALS[@]}"; do files+=("$WASMTIME_MISC/$f"); done
            ;;
    esac
    echo "${files[@]}"
}

FILES=($(collect_files))
CONVERTED=0
SKIPPED=0
FAILED=0
COPIED=0

for src in "${FILES[@]}"; do
    [ -f "$src" ] || continue

    if is_skipped "$src"; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    name=$(basename "$src")
    base="${name%.*}"
    ext="${name##*.}"

    # For subdir files, flatten name with dir_ prefix (e.g. simd/foo.wast → simd_foo.wast)
    relpath="${src#$WASMTIME_MISC/}"
    if [[ "$relpath" == */* ]]; then
        prefix="${relpath%%/*}"
        # Normalize: function-references → funcref, custom-page-sizes → custom_page_sizes
        prefix="${prefix//-/_}"
        [ "$prefix" = "function_references" ] && prefix="funcref"
        flat_name="${prefix}_${name}"
        flat_base="${prefix}_${base}"
    else
        flat_name="$name"
        flat_base="$base"
    fi

    # Copy to wast dir
    cp "$src" "$WAST_DIR/$flat_name"
    COPIED=$((COPIED + 1))

    # Convert to JSON
    if [[ "$ext" == "wast" ]]; then
        if wasm-tools json-from-wast "$WAST_DIR/$flat_name" -o "$JSON_DIR/$flat_base.json" --wasm-dir "$JSON_DIR/" 2>/dev/null; then
            CONVERTED=$((CONVERTED + 1))
        else
            echo "WARN: failed to convert $flat_name"
            FAILED=$((FAILED + 1))
        fi
    elif [[ "$ext" == "wat" ]]; then
        # .wat files: just validate/copy the wasm — run_spec.py can't use them directly
        # We'll handle .wat files separately if needed
        echo "NOTE: $flat_name is .wat (not .wast) — skipping JSON conversion"
        SKIPPED=$((SKIPPED + 1))
    fi
done

echo ""
echo "Copied: $COPIED, Converted: $CONVERTED, Skipped: $SKIPPED, Failed: $FAILED"
echo "WAST dir: $WAST_DIR/"
echo "JSON dir: $JSON_DIR/"

# Custom generators for proposals that wast2json cannot handle
echo ""
echo "--- Custom proposal generators ---"
if [ -f "$WAST_DIR/wide-arithmetic.wast" ]; then
    python3 test/e2e/gen_wide_arithmetic.py && echo "OK: wide-arithmetic" || echo "FAIL: wide-arithmetic"
fi
python3 test/e2e/gen_custom_page_sizes.py && echo "OK: custom-page-sizes" || echo "FAIL: custom-page-sizes"
