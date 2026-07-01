# v128-in-GC correctness class: comprehensively swept (2026-06-21)

A focused correctness-sweep of every path where a **v128 value meets a GC/reftype
construct**. The trigger pattern was "a switch/helper that assumed ≤8-byte
elements" (the D-493/D-495 shape). Result — all paths VERIFIED on JIT (both
arches where codegen differs), interp is SIMD-JIT-only so it traps at v128.const:

| path | status |
|---|---|
| `select (result v128)` (typed 0x1c/0x7B) | FIXED D-491 |
| `select t` with GC abstract reftypes | FIXED D-492 (arm64 select→gpr64) |
| `array.new_data` / `array.init_data` v128 | FIXED D-493 (u64-pack→memcpy) |
| `array.get` v128 | already worked (D-460) |
| `array.set` v128 | works (v128-aware store) |
| `array.copy` v128 | works (esz-byte copy) |
| `struct.new` / `struct.get` / `struct.set` v128 field | works |
| `array.fill` / `array.new` with a v128 VALUE | **D-495 — guarded** (was a guest-triggerable host panic: fill helper takes value as u64; esz>8→clean trap; proper 16-byte pointer-marshal deferred) |

Also grepped all `jit_abi` `callconv(.c)` helpers taking a value as `u64`
(`asBytes(&v)[0..esz]` risk): only `jitGcArrayFill`/`jitGcAllocArrayFill` (D-495).
`table.grow` init = reftype (≤8B), atomics = ≤8B memory → neither is v128-vulnerable.

## Takeaway

The GC slot model is `element.size = slot_size` (8B scalars/refs, 16B v128). Any
NEW GC value path must handle the 16B v128 slot. The remaining gap (D-495) is the
single helper-based VALUE-fill path; everything element-wise/inline is v128-aware.
Don't re-probe this class — it's clean except D-495.
