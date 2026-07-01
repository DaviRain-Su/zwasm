# GC type-identity table gated on heap-need misses func-only subtyping

2026-06-02 (D-232 / ADR-0131). 4 `gc/type-subtyping` interp `assert_trap` fails
("indirect call" traps that didn't fire) root-caused to a gating mismatch, not a
subtype-algorithm bug.

`gc_type_infos` (supertype chains + canonical ids + finality — what
`concreteReaches` needs for the §3.3.5.5 `call_indirect` subtype check) was
materialised only when `needs_gc_heap` (a struct/array/heap-reftype byte scan).
Modules that declare `sub`/`sub final` on FUNC types but allocate nothing get
`needs_gc_heap=false` → no table → `concreteReaches` blind → the
`sigEq(callee,expected)` arm short-circuits, and its purely-structural compare
accepts structurally-equal-but-DISTINCT types (`(sub (func))` vs
`(sub final (func))`; super-as-sub). The type system had the right algorithm; the
table just wasn't built.

**The discriminating probe was the whole game.** An env-gated print of
`sigEq` / `concreteReaches` / `gti-present` per `call_indirect` showed all 23
`sigEq=true, concreteReaches=false` accepts had **gti=false**, and only 4 were
bugs (19 were genuinely non-GC modules where `sigEq` is correct). That one bit
(gti present?) separated "fix" from "regress 19" and dictated the shape: don't
gate `sigEq` off broadly — broaden *when the table is built*, then make
`concreteReaches` authoritative only where it exists.

**Rules:**

1. When a runtime check has a "fast structural path OR precise path" shape and the
   precise path silently degrades to false when its data is absent, the bug is
   often the DATA GATE, not the algorithm. Probe "is the precise data present?"
   before touching the algorithm.
2. A capability gate sized to one trigger (heap allocation) under-serves a
   sibling need (type identity for subtype checks) that travels with the same
   feature but not the same trigger. Decouple: gate each consumer by what IT
   needs (`usesTypeSubtyping` = any non-final OR any declared super), not by a
   neighbour's trigger.
3. Preserve a zero-overhead invariant (ADR-0115) while broadening with a cheap
   byte pre-filter (`sub` 0x50 / `sub final` 0x4F) that skips the precise decode
   for the common (non-subtyping) case — precise where it matters, free elsewhere.
4. A bare `(func)` ≡ `(sub final (func))`-no-super (canonically structural) — so
   "uses subtyping" must mean non-final OR has-super, NOT "uses the sub keyword".

Same family as `2026-06-02-detection-without-enforcement-dead-gate` (both: the
mechanism existed; the trigger/wiring was the gap).
