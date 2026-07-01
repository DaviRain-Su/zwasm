---
name: validator dead code in runtime path
description: D-042 root cause — `compileOne` skips validator entirely; naive wire-in breaks 69 valid fixtures because compileOne lacks module context (globals/tables/data).
type: feedback
---

## What happened (D-042 investigation)

The 27 SKIP-VALIDATOR-GAP fixtures surfaced by `assert_invalid`
in §9.7 / 7.5-close-a all map to the same root cause:
`src/engine/codegen/shared/compile.zig:compileOne` calls
`lowerer.lowerFunctionBody` directly without a prior
`validator.validateFunction` step. The validator at
`src/validate/validator.zig` is **dead code** for the runtime
JIT path. Type-mismatch / unknown-local rules in the validator
are correctly authored (popExpect / localType bounds-check) but
never run.

## Naive fix attempted (and reverted)

Adding `validator.validateFunction(sig, locals, body, func_sigs,
&.{}, module_types, 0, &.{}, 0)` before
`lowerFunctionBody` in compileOne:

- spec_assert 185/0/47 → 145/69/20 (= 0 skip-impl + 20 skip-adr).
  The 27 originally-targeted fixtures DO move from skip → pass,
  but **69 previously-valid fixtures now FAIL** because the
  validator's empty `globals`/`tables`/`data_count`/`elem_count`
  context wrongly rejects modules that legitimately use those
  features (handcrafted_globals, handcrafted_mem, etc.).

## How to apply

When wiring the validator in for real:

1. Extend `compileOne` signature to accept `module_globals:
   []const validator.GlobalEntry`, `module_tables: []const
   zir.TableEntry`, `data_count: u32`, `elem_count: u32`.
2. Update `compileWasm` (in `src/engine/runner.zig`) to decode
   global / table / data / element sections and pass them
   through.
3. Verify both: (a) the originally-targeted 27 fixtures move
   skip → pass, (b) no regressions in the existing 185 PASS.

The naive `&.{}` shortcut is **silent miscompile risk** going
the other way — it rejects valid modules. Don't take it as a
foundation step; the proper threading must land atomically.

## When this rule applies

Anywhere a validator is added to a previously-bypassed compile
path, the first sanity check is "does the validator have
**every** input it needs to type-check the existing test
corpus?". If any input is missing, the validator will
false-reject and must not be enabled until the threading
lands.

References: commit `e0c1946` (handover retarget), commit
`fedae43` (mta close), `.dev/debt.md` D-042. Citing: D-042's
follow-up split into D-042-prep (thread module context) +
D-042-impl (enable validator).
