# GC corpus block is VALIDATE, not parse (D-197 split + error histogram)

**Date**: 2026-05-29
**Cycle**: 10.G-wasmgc cycle 127
**Citing**: `e14380ec` (D-197 CompileError split)

## Finding

After cyc124-126 (type-section parse + subtype validate), the gc corpus
still showed 51 `compile FAIL: ParseFailed`. cyc127 split
`Engine.CompileError` into `ParseFailed` vs `ValidateFailed` (D-197):
the spec runner now reports **gc ParseFailed=0, ValidateFailed=51**.

**GC type-section PARSE is COMPLETE.** Every remaining gc compile
failure is a VALIDATE failure (frontendValidate / per-function
validator), NOT a parse gap. This redirects the whole bundle: the next
chunks are validator GC-op work, not more parsing.

## Validate-error histogram (whole wasm-3.0-assert corpus)

From a throwaway probe (reverted) on the per-function validate `catch`:

| error | count |
|---|---|
| StackTypeMismatch | 51 |
| InvalidAlignment | 37 |
| StackUnderflow | 28 |
| InvalidFuncIndex | 17 |
| ArityMismatch | 16 |
| NotImplemented | 10 |
| BadBlockType | 3 |
| UndeclaredFuncRef | 2 |
| BadValType | 1 |

**Caveat (load-bearing)**: this mixes VALID fixtures failing (real gaps)
with `assert_invalid` fixtures correctly rejected (e.g. many
InvalidAlignment are correct rejections of over-aligned-access invalid
fixtures). The histogram is NOT a pure bug list. Next step must
ATTRIBUTE each failure to its assertion type before fixing.

Also observed: i31 fixtures (i31.0/1/3/4/5/6) fail validate BEFORE the
per-function loop (preDecodeSectionBodies / validateTypeSection / an
early `return false`), not in the func body — a distinct sub-class.

`NotImplemented ×10` = struct.get_s/u + array.get_s/u (packed types,
deferred per ADR-0121 D3) — genuinely not-yet-implementable.

## Lesson

The D-197 single-`ParseFailed` collapse hid a whole-bundle
mis-targeting: I'd assumed (cyc126 handover) the remaining gc failures
were "mostly execution-blocked". They are neither execution nor parse —
they are VALIDATE. Splitting the error at the type level (cheap, no env
var, no probe) is what made this visible permanently. When a corpus
metric is opaque, invest in making the failure ATTRIBUTABLE before
guessing at fixes.

## Related

- ADR-0124 (GC subtype validation); D-197 (error collapse, now split)
- `2026-05-29-gc-subtype-finality-byte-direction-masked.md`
- `2026-05-29-zig-run-step-cache-stale-diag.md` (DIRECT-binary discipline)
