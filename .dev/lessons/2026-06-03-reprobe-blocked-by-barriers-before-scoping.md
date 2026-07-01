# Re-probe a `blocked-by` barrier before scoping it as multi-cycle

**Date**: 2026-06-03 · **Context**: D-240 (typed-ref elem-into-table) closed by a one-line flip

## Observation

D-240 was recorded `blocked-by: JIT runtime support for typed/abstract-ref
tables`, with a verified-at-the-time note: "loosening `compile.zig` elem-vs-table
`eql`→`valTypeIsSubtype` ALONE makes the JIT SEGV at runtime (RUN=139)". On that
basis ~3 cycles scoped D-240 as a deep multi-cycle bundle (a new typed-ref table
runtime).

It wasn't. Re-running the exact probe (flip the check, build the JIT spec runner
by-mtime, run `ref_is_null.0` + `gc/i31.6`) showed **zero SEGV, zero new fail,
assert_invalid intact, +28 JIT return pass**. The barrier had dissolved: D-218
(i31-encoded elem segments) + the null-safe funcptr-derive in `table.init` landed
in *other* cycles between the original probe and now, retro-fixing the runtime the
SEGV depended on. The discharge predicate's part (1) "implement the runtime" was
already satisfied; only part (2) "flip + verify" remained.

## Rule

A `blocked-by` debt barrier is a **point-in-time** measurement. When the named
barrier is "runtime gap X" and *any* later work has plausibly touched X, the
Step 0.5 barrier-dissolution check must **actually re-run the cheapest probe**
before re-scoping — never inherit a stale `verified-at` SEGV/fail as still-true.
"The handover says it SEGVs" is not evidence; the run is. Cost here: one throwaway
flip + one build (≈8 min) vs ~3 cycles of mis-scoping it as a bundle.

Corollary: prefix every barrier note with the SHA it was verified at (per
`investigation_discipline.md` §1 / `handover_doc_discipline.md` §2), and treat a
barrier whose verifying SHA predates unrelated runtime churn as **unverified**.

## Second instance (same session): D-210 wrong root-cause from no disassembly

`return_call_indirect.0`'s `UnsupportedOp` (func[36] pc=12) was characterized
across several cycles as "return_call_indirect INSIDE a try_table (TC×EH
integration, deep)" — and conflated with the D-210 debt row (cross-module
frame-consuming tail-call needing a prologue cohort stack-save). Disassembling
func[36] with `wasm-tools print` showed it has **NO try_table** — it's a plain
dispatcher with three `return_call_indirect`s on tables 0/1/**2**; pc=12 is the
table-1 call, tripping the `table_idx != 0` gate. The real fix was same-module
**multi-table** support (mirror `emitCallIndirect`'s slow path) — a tractable
emit chunk, not a TC×EH bundle, and unrelated to the D-210 debt row.

Rule extension: a `func[K] pc=N` blocker characterization MUST be grounded by
actually disassembling func[K] (`wasm-tools print`) before scoping the fix or
attributing it to a debt ID — an op-name + "probably in <feature>" narrative is a
guess, and guesses calcify into "deep multi-cycle" mis-scopings.

Related: ADR-0133 (§10-exit scope); D-218 (i31 elem encode); D-210 (the *actual*
cross-module-cohort debt, still open); `investigation_discipline.md`;
[[2026-06-03-eh-on-jit-blocker-is-validator-not-dispatch]] (trust CODE/disasm over narrative).
