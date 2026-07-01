# wasmtime canonicalize-nan fixtures over-assert exact NaN bits

**Date**: 2026-06-16
**Context**: ADR-0192 wasmtime misc_testsuite differential, top-level core bucket.

## Observation

`canonicalize-nan-scalar.wast` asserts the EXACT canonical NaN bit pattern
(`0x7fc00000` / `0x7ff8000000000000`) as the result of `f32.demote_f64` /
`f64.promote_f32` of a NaN. zwasm produced a different (sign/payload-preserving)
quiet NaN → exact-bit compare failed.

This is NOT a zwasm bug. Per Wasm spec §4.3.3, `fdemote`/`fpromote` of a NaN
return an **arbitrary arithmetic NaN** (the result payload is nondeterministic).
The official testsuite (`conversions.wast`, `float_misc.wast`) asserts these
with `nan:canonical` / `nan:arithmetic` patterns that accept the whole NaN set —
which is why zwasm is 100% spec there. wasmtime's fixture asserts the exact
canonical bits because wasmtime *happens to* canonicalize; zwasm's `@floatCast`
(numeric_conversion.zig:174/195) yields a conformant arithmetic NaN instead.

## Rule

When a differential corpus (wasmtime/etc.) asserts EXACT FP-NaN bits for an op
whose spec result is "an arithmetic/canonical NaN" (demote, promote, arithmetic
ops on NaN inputs), a bit-mismatch is **engine-divergence within spec latitude,
not a bug** — confirm zwasm passes the official `nan:canonical`/`nan:arithmetic`
assertions for the same op (it does) and move on. Only a non-NaN result (or the
wrong sign where the spec pins it) is a real bug. Don't "fix" zwasm to match
wasmtime's exact canonicalization — that would add work for zero spec benefit.
