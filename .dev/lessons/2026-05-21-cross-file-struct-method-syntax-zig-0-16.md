# Cross-file struct method syntax requires pub on struct + methods (Zig 0.16)

**Date**: 2026-05-21
**Keywords**: Zig 0.16, usingnamespace, method syntax, struct, pub, cross-file, extract, refactor, validator_simd, ADR-0083, free function, self
**Citing**: `860281bb` (ADR-0083 impl — validator_simd.zig extraction)

## What happened

ADR-0083's carve cycle (validator_simd.zig extraction) needed to
move ~420 LOC of methods (defined inside `pub const Validator =
struct {...}`) into a sibling file. Initial naive approach: move
the method bodies verbatim, expecting Zig's method syntax
`self.method()` to keep working from the new file because both
files are in the same module graph.

Build failed with 14 errors:

```
src/validate/validator_simd.zig:315:13: error: 'pushType' is not marked 'pub'
    try self.pushType(.v128);
        ~~~~^~~~~~~~~
src/validate/validator_simd.zig:369:13: error: no field or member function named 'readSimdMemarg' in 'validate.validator.Validator'
    try self.readSimdMemarg(max_align_log2);
```

Two distinct sub-problems surfaced.

## Root cause

Zig 0.16 removed `usingnamespace`. In its absence, a struct's
methods can only be defined **inside the struct's `struct {...}`
declaration**. Moving a method to a separate file means the
function is no longer a method on the struct — it becomes a free
function. This has two cascading constraints:

1. **The struct itself must be `pub`** so the sibling file can name
   `validator.Validator` to use as the `self` parameter type.
   `const Validator = struct {...}` (non-pub) blocks cross-file
   reference at the struct level.

2. **Methods referenced via `self.method()` from the sibling
   file must be `pub`**. Method syntax `instance.method()`
   desugars to `Type.method(&instance, ...)`. The lookup goes
   through `Type`'s namespace — if the method declaration is
   non-pub, the sibling file can't reach it. Field access
   (`self.field`) does not have this constraint — fields are
   accessible across files as long as the struct is reachable.

3. **Functions that moved out of the struct become free
   functions**. Their call sites change shape: `self.helperFn()`
   inside the extracted file must become `helperFn(self)` because
   `helperFn` is no longer a method on `Validator`. This applies
   to ALL intra-extracted calls — both calls between the moved
   functions and calls to helpers that also moved.

## Fix (or path forward)

Four-step pre-extraction checklist for per-file ADRs targeting
struct-method-heavy files (step 4 added by ADR-0094, 2026-05-21):

1. **Identify struct + moved methods that need pub-ification**.
   - The struct declaration: `pub const Validator = struct {...}`.
   - Every method the moved code calls via `self.X()` syntax
     where `X` is defined in the original file (e.g. `popExpect`,
     `pushType`). These need `pub fn X(...)` in the original file.

2. **Identify intra-moved calls to convert to free-function
   form**.
   - Methods that moved alongside (e.g. SIMD helpers
     `readLaneIdx`, `readSimdMemarg`): every `self.X(args)` call
     to a moved helper becomes `X(self, args)`. The function
     itself becomes a free `pub fn X(self: *Validator, args)
     ...` in the extracted file.

3. **Field accesses stay**. `self.body`, `self.pos`,
   `self.memory_count` — these work cross-file as long as the
   struct itself is pub.

4. **Annotate each pub-ified-for-sibling-only decl with the
   SIBLING-PUB marker** (per ADR-0094):

   ```zig
   // SIBLING-PUB: <sibling files> (per ADR-NNNN extraction)
   pub fn helperX(...) ...
   ```

   `scripts/check_sibling_pub.sh --gate` (wired into
   `gate_commit.sh`) verifies no file outside the authorized
   sibling list calls the marked decl. The marker documents
   the deliberate "pub for sibling reach, not for the world"
   intent and bounds the leak.

Mechanical: Python regex over the extracted block worked
cleanly for ADR-0083 (50 intra-SIMD calls + 4 helper-call
sites). Each `self\.<name>\(args\)` → `<name>(self, args)`.

## Why this didn't surface earlier

ADR-0081 (emit_setup.zig) extracted **pure top-level helpers** —
functions defined outside any struct. They had no `self.X()`
syntax involvement. ADR-0082 (dispatch_collector_ops.zig)
extracted **pure data** (imports + tuple) — no methods at all.

ADR-0083 was the first per-file ADR to target a struct-
method-heavy file. The lesson is structural to Zig 0.16's
post-`usingnamespace` reality: struct methods are file-locked.

## Implication for future per-file ADRs

When a Step 0 survey identifies a candidate file as struct-
method-heavy (one big `pub const Foo = struct {...}` containing
> 50% of the file's LOC), the ADR's "Implementation order"
section MUST include:

- A pre-impl audit step listing all `self.X` patterns in the
  block-to-move.
- An explicit note that struct + helpers need `pub` (touched in
  the impl commit).
- Caller-side fanout: any external module that uses
  `Foo.method()` form (vs `instance.method()`) needs no change;
  any caller using `self.method()` inside the moved code needs
  the conversion.

Candidates with this shape from D-141:

- `src/ir/lower.zig` (1109 LOC) — `Lowerer = struct {...}`
- `src/validate/validator.zig` (1363 LOC after ADR-0083) — `Validator = struct {...}`
- `src/engine/codegen/arm64/emit.zig` (1630 LOC) — one big `compile()` fn, NOT struct-method-heavy
- `src/engine/codegen/x86_64/inst.zig` (1328 LOC) — instruction encoder catalog, mostly top-level fns

ADR-0081 / 0082 pattern applies to the latter two; ADR-0083
pattern applies to lower.zig + future validator.zig follow-up.

## Related

- ADR-0081 — emit_setup.zig (pure top-level helper extraction, no cross-file methods)
- ADR-0082 — dispatch_collector_ops.zig (pure data extraction, no methods)
- ADR-0083 — validator_simd.zig (FIRST cross-file struct-method extraction; this lesson's subject)
- ADR-0094 — SIBLING-PUB marker + audit grep (the pub-leak
  encapsulation discipline; step 4 above)
- `.claude/rules/zig_tips.md` — Zig 0.16 idioms; should reference this lesson
  when discussing `usingnamespace` removal.
- Lesson `2026-05-21-emit-zig-survey-per-op-pattern-already-absorbed.md`
  — sibling: ADR-0080 Withdrawn for over-estimate. This lesson
  is the second post-ADR-0080-pivot finding shaping future per-file ADRs.
