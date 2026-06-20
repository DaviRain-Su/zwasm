# When threading a new index width, audit ALL memory-address op-families

**Date**: 2026-06-20 · **Refs**: D-324, @06d0c2ea1,
`src/validate/validator_simd.zig`

## Observation

memory64's `idx_type` (i32 vs i64 memory address) is consumed by FOUR distinct
op-families, each with its OWN address-pop site in the validator:

1. **regular** load/store (`opLoad`/`opStore` — `readMemargCheckAlign` →
   `memIdxTypeAt`).
2. **bulk** memory.init/copy/fill (`opMemoryCopy`/`opMemoryInit`/`opMemoryFill`).
3. **atomic** load/store/rmw/cmpxchg/wait/notify (0xFE — all `memIdxTypeAt`).
4. **SIMD** v128.load*/store*/load_lane/store_lane (0xFD — `readSimdMemarg`).

The original memory64 threading (D-324) wired families 1–3 but **silently
missed family 4** — the SIMD memory ops kept a hardcoded `popExpect(.i32)`. The
miss was invisible for ~weeks because the spec corpus has no memory64+SIMD test
(the SIMD proposal predates memory64) and `simd_assert` only uses i32 memory. A
smith fuzz axis combining `memory64-enabled` + `simd-enabled` surfaced it
(`type mismatch: expected i32, found i64 at op 0xfd` on every module).

## The lesson

When you thread a NEW operand-width / index-type through "the load/store
validator," it is NOT one site — enumerate every op-family that takes a memory
ADDRESS (regular, bulk, atomic, SIMD; and the runtime/JIT mirrors of each) and
fix them as a set. Grep `popExpect(.i32)` + `readMemarg`-family callers across
`validator.zig` AND `validator_simd.zig` (separate file = easy to miss). The
fuzz axis that catches a missed family is the FEATURE COMBO the spec corpus
doesn't cover (here memory64 × SIMD) — combine two orthogonal proposals in one
smith config to flush these out.

Counterpart: table64 (D-475) is the SAME shape one level up — `table.get/set/…`
+ `call_indirect` each needed the table's `idx_type`; verified all 8 + the
SIMD-on-table-doesn't-exist boundary.
