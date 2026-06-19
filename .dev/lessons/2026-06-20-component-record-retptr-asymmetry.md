# Cross-component non-flat RESULT: lift returns a ptr, lower passes one

**Observed**: D-305(b2) flat-record result (2026-06-20). A `() -> record`
crossing a component boundary nearly got the wrong trampoline — I started
by copying the string-result path, which allocates a callee return area
and passes it INTO B. That is wrong for the record fixture.

**The canon ABI asymmetry** for a result exceeding `MAX_FLAT_RESULTS=1`:

- **LIFT side** (the producer / callee B's exported func): core signature
  is `(result i32)` — B allocates its own storage, writes the value, and
  **RETURNS the pointer**. B takes no return-area param.
- **LOWER side** (the consumer / caller A's lowered import): core
  signature is `(param i32)` — **A allocates a return area and PASSES the
  pointer in**, then reads the value back from it.

So the boundary glue bridges the two: invoke B's producer with **no value
args**, read its **returned** i32 pointer, then copy the result into A's
**passed-in** retptr. (`recordRetTrampoline` does exactly this.)

**Why the string-result path looked different**: `retPtrMarshal`
allocates a callee area and passes it to B because that fixture's B
producer was authored retptr-in. Do NOT generalize one fixture's B
shape — read the actual core sig from the `.wat` / `wasm-tools print`.

**How to apply**: for a flat record (no internal string/list/handle
pointer) the cross-boundary lower is a **raw `@memcpy` of `sizeOf(record)`
bytes** B→A — no per-field lift/lower relocation. Records CONTAINING a
string/list still need recursive `canon.store/load` (deferred). And a
named record at a boundary needs the nominal-type spelling
`(export $pe "point" (type $point))` + alias wiring, not a bare type
index (wasm-tools else rejects "func not valid to be used as export").
See [[D-305]].
