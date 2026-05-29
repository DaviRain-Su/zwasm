# type-subtyping gc ValidateFailed family is RTT-blocked (br_on_cast), not a subtype-coercion gap

**Date**: 2026-05-29 (@ a763d44a, cycle 143)
**Keywords**: WasmGC, 10.G, type-subtyping, br_on_cast, br_on_cast_fail,
0xFB 0x18, 0xFB 0x19, RTT, ADR-0116, subtypeCtx, gcConcreteReaches,
ref.eq, validateTypeSection, op-probe instrumentation, StackTypeMismatch

## What was tried

Three hypotheses for why type-subtyping.6/7/… fail `ValidateFailed`
with `StackTypeMismatch`, each ruled out:

1. ~~validateTypeSection edge case (`s >= i` forward-supertype refs,
   multi-supertype)~~ — REJECTED: the failures are in the **function
   body** loop, not the type section.
2. ~~concrete→concrete subtype chain missing in `subtypeCtx`~~ —
   REJECTED: added `subtypeCtx .concrete => gcConcreteReaches(idx,
   e_idx, supertypes)` + threaded a `supertypes` field through the
   validator → **gc return stayed flat at 62** (no fixture exercised
   it). The rule is *correct* but currently unobservable.
3. ~~ref.eq (`0xFB 0x13`) too strict on concrete refs~~ — REJECTED:
   `isRef()` is `self == .ref`, which already covers concrete
   `(ref $t)`. The 3 ref.eq `StackTypeMismatch` are **invalid
   fixtures correctly rejected** (non-ref operands).

## The finding (how it was localized)

A temporary op-probe in `Validator.run` — print `op`/`sub` on dispatch
error — gave the StackTypeMismatch histogram across the gc corpus:
**`0xFB 0x18` (br_on_cast) ×6 + `0xFB 0x19` (br_on_cast_fail) ×3**
dominate the GC-relevant return-fixture failures. br_on_cast needs a
**runtime type test** (RTT) against `ObjectHeader.info`; the validator
`opBrOnCast` is a byte-consuming stub that round-trips the popped
reftype via `.eql` (no narrowing, no cast). RTT is **deferred per
ADR-0116** — so the whole type-subtyping ValidateFailed family is
RTT-blocked. There is no quick non-RTT win in it.

## Lessons

- **Instrument the op, not the symptom.** "StackTypeMismatch ×N" is
  opaque; the op-byte histogram named the blocker (br_on_cast) in one
  run, after two wrong guesses. Same shape as the cyc127 attributability
  lesson (`gc-corpus-block-is-validate-not-parse`).
- **Don't land an unobservable validator shape change** (the
  concrete-chain `subtypeCtx` fix) — its only exerciser is itself
  RTT-blocked. Discarded per `spike_discipline.md` §2 (D-153 pattern);
  re-derive it *inside* the RTT cycle where it becomes observable.

## Related

- `.dev/lessons/2026-05-29-gc-corpus-block-is-validate-not-parse.md`
  (split the error to make failures attributable — same discipline)
- ADR-0116 (RTT deferred); ADR-0121 (GC type-info substrate)
