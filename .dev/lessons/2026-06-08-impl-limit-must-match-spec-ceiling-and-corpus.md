# A new validation "limit" must match the spec ceiling AND clear the spec corpus

**Date**: 2026-06-08
**Tags**: table limits, MAX_WASM_TABLE_ENTRIES, element-segment count vs table min,
spec §3.2.4, conformance regression, table.6, too-strict validator, DoS-vs-spec,
borrowed-constant-misuse, instantiation-resource-vs-validation

## What happened

While hardening the decoder against alloc-DoS from crafted declared sizes, I
added a 10,000,000 cap on a table TYPE's declared `min`, sourced from
wasmparser's `MAX_WASM_TABLE_ENTRIES`. This rejected the **spec-valid**
`wasm-2.0` `table.6` fixture (`(table funcref 0 0xffffffff)`) with
`InvalidTableLimit` — a deterministic conformance regression (ubuntu
`test-spec-wasm-2.0-assert`: 25437 passed, **1 failed**). It looked like the
session-2 "ubuntu heisenbug" but was 100% deterministic; the Mac loop missed it
because the spec-assert runner is test-all-only (cf.
`fixtures-under-edge-cases-run-by-edge-runner`).

## Root cause

I misused the borrowed constant. `MAX_WASM_TABLE_ENTRIES` in wasmparser bounds an
**element segment's element count** (`core.rs:170`, `validate_count`), NOT a
table type's `min`. A table type's limits are only checked for `min ≤ max`
(`check_limits`); the spec puts **no sub-2^32 ceiling** on a table's `min`. The
`_MAX_WASM_TABLE_SIZE` name with the `_` prefix = deliberately unused. Reserving
a huge table is an **instantiation-time resource** decision (a limiter, D-316),
not a **validation** error.

## Fix (@3ab0494f)

Reverted the table-min cap on both validate paths (interp `frontendValidate` +
JIT `engine/compile.zig`) to `max < min` only. Dropped the misused
`MAX_TABLE_ENTRIES` constant. Kept the memory page ceilings
(`MAX_MEMORY_PAGES_I32/I64` = 65536 / 2^32) — those ARE spec-defined (§A.1) and
correct. Replaced the wrong facade test + removed the wrong fuzz seed.

## Rules

1. Before adding ANY validation limit, confirm whether the spec defines a
   ceiling for THAT field. Memory pages: yes (§A.1). Table `min`: no (full u32).
   A too-strict validator is a conformance bug, as bad as a too-lax one.
2. A borrowed constant from another runtime carries the OTHER project's
   semantics — verify what it actually bounds (element-count ≠ type-min) before
   reusing the number.
3. DoS-from-huge-declared-size belongs at the RESERVATION site (instantiation /
   a resource limiter), not in validation, when the spec admits the value.
4. Any new reject-path MUST be run against the full spec corpus (test-all /
   3-host) before trusting it — the Mac unit loop does not exercise the
   spec-assert runners.
5. A "1 failed / N passed" on one host that smells like flakiness is a
   deterministic regression until proven otherwise: extract the `FAIL` line
   first (`grep '^FAIL'`), don't assume the known heisenbug.
