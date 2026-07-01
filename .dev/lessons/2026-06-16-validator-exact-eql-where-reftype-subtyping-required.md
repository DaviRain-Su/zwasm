# Validator exact-`eql` type checks are latent subtyping bugs wherever reftypes flow

**Date**: 2026-06-16
**Context**: Front ③ GC-corpus expansion. A Guile-Hoot (Scheme→wasm-gc) module
failed zwasm validation at func #36 on `return_call` — not a Hoot/import problem
but a real zwasm spec-conformance gap. Investigating the class surfaced three
sibling sites.

**Finding**: several validator type-matching sites used exact `ValType.eql`
where Wasm 3.0 requires **subtyping**. The spec testsuite + hand-written unit
tests passed because they exercise these boundaries only with types that
coincide under eql (e.g. `funcref`==`funcref`); a real Wasm-GC program flows
non-null `(ref $t)` / concrete refs through them and trips the exact check.

Sites found (all reachable once reftype subtyping flows):
- **`return_call*` result check** (`checkResultsMatchFnReturn`) — callee result
  must be `<:` the enclosing fn return (a tail call forwards results, so `end`'s
  subtyping applies). Fixed `9064faa5` → `self.subtypeCtx`.
- **`table.copy`** — Wasm 3.0 §3.3.6: source elem `<:` dest elem, not equal
  (copy a `(ref func)` table into a `funcref` table). Fixed `480809af`.
- **`br_table` label check** (`labelTypesEq`, §3.3.8.8) — labels need only share
  a common operand subtype, not be pairwise-equal. NOT a one-line fix (restructure
  to check operands against each label) → **D-452**, latent.

eql IS correct for numeric-only contexts (typed `select`, validator.zig:2893 —
i32/i64/f32/f64/v128 have no subtyping) and for exact-match-by-design tag/exnref
signatures (try_table catch). Don't blanket-swap.

**How to apply**: when auditing the validator (or adding a type-matching check),
`grep -nE '\.eql\(' src/validate/validator.zig` and classify each site:
numeric/exact-by-design (eql OK) vs **reftype-capable** (must use `subtypeCtx` —
the same oracle `popExpect` uses). The spec testsuite under-covers cross-
(null/non-null)(concrete/abstract) ref subtyping at branch/copy/return/call
boundaries; a real Wasm-GC source-language corpus (Hoot, dart2wasm) is the
forcing function that exposes them. Cross-ref the front-③ probe thesis: a diverse
real-toolchain corpus finds engine bugs the synthetic suites miss (cf. the
AssemblyScript probe → D-451 instantiation divergence, same campaign).
