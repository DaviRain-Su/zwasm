# Skip — wast cross-module action directives

- **Status**: Superseded by §9.9-III + §9.12-E DONE (2026-05-22 per ADR-0104) — Cross-module dispatch (§9.9-III [x]) + SKIP-CROSS-MODULE-IMPORTS discharge (§9.12-E [x]) make this skip-ADR's framing obsolete. The 286 distiller-level emissions are retire candidates; runner-side filter removal pending verification at §9.13-0 reconcile.
- **Date**: 2026-05-16 (originally landed as `skip-adr-cross-module-action` at §9.9 / 9.9-l-1b-d093-d37; vocab-renamed at §9.9 / 9.9-l-1b-d093-d60 to satisfy `check_skip_adrs --gate` per D-131)
- **Author**: zwasm v2 / continue loop
- **Tags**: phase-9, skip-adr, spec-conformance, cross-module
- **Manifests covered**: 286 entries across `elem`, `exports`, `linking`, `memory_grow`, `table_grow` corpora

## Directive

Wast directives whose `action` carries a `module` field (e.g.
`(assert_return (invoke $Mf "fn" ...))`,
`(assert_trap (invoke $Mt "fn" ...))`, or bare
`(invoke $M "side_effect" ...)`) target a previously
`(register "alias" $M)`-bound peer module. They are the wast
harness's mechanism for asserting cross-module composition
properties.

## What v2 does today

The `spec_assert_runner_non_simd` distiller
(`scripts/regen_spec_2_0_assert.sh`) detects the `module` field
in each action's JSON command and emits a
`skip-adr-skip_cross_module_action ...` line at distillation
time — independent of the action kind (assert_return,
assert_trap, bare action). The runner's `classifySkipLine`
matches the `skip-adr-` prefix and routes the entry to
`skipped_adr++`. Companion behaviour: every `(register ...)`
directive itself is also a no-op for our scaffold and lands as
`skip-adr-skip_cross_module_register` (see
[`skip_cross_module_register.md`](skip_cross_module_register.md)).

## Why v2 declines

Same scope decision as
[`skip_cross_module_register.md`](skip_cross_module_register.md):
cross-module composition is Track-D / Phase-10+ scope per
ADR-0029 + ADR-0050 + D-079. Honest implementation of
`(invoke $module ...)` requires an instance-aware spec harness
that:

1. Persists each `module` directive's compiled instance into a
   wast-scope instance registry keyed by the module's `$name`.
2. Maps `(register "alias" $M)` to bind that instance under the
   import key `"alias"`.
3. Resolves `(invoke $module "fn" ...)` by looking up the
   target module's instance in the registry, marshalling args
   across the AAPCS64 / SysV ABI boundary, and propagating
   trap state back to the assert wrapper.
4. Threads the `module_state_diverged` flag (see
   [`skip_host_state_diverged.md`](skip_host_state_diverged.md))
   across cross-module observations — divergent host state in
   one module can still skip downstream observation asserts in
   another.

That work is tracked under the broader Phase 10+ cross-module
imports row (D-079 umbrella; D-105 + D-126 sub-cases).

## What v2 needs to fix this honestly

The Phase 10+ cross-module imports + instance-aware refactor
row. When that lands, the natural sequence is:

1. Replace `hasUnbindableImports` with a per-import resolver
   that consults the per-`.wast` instance registry.
2. Reroute the distiller's `assert_return` / `assert_trap` /
   `action` arms to emit real `(invoke {module} {fn} ...)`
   directives instead of the
   `skip-adr-skip_cross_module_action` family.
3. Retire this skip-ADR alongside
   `skip_cross_module_register.md` and the associated debt
   rows (D-079 + D-082 + D-105 + D-126).

## Removal plan

When the Phase 10+ cross-module imports row lands and the
distiller's `assert_return` / `assert_trap` / `action` arms
emit real cross-module dispatch directives, retire this
skip-ADR. The ADR itself stays as historical record per
ADR-0029 Path B conventions.

## Removal condition (machine-checkable)

> Every `skip-adr-skip_cross_module_action` line in
> `test/spec/wasm-2.0-assert/**/manifest.txt` is replaced by a
> real `assert_return` / `assert_trap` / `invoke-action`
> directive against an instance-aware runner, and
> `grep -r 'skip-adr-skip_cross_module_action'
> test/spec/wasm-2.0-assert/` returns zero hits.

## Implementation (per ADR-0029 Path B, since §9.9 / 9.9-l-1b-d093-d37)

The distiller `scripts/regen_spec_2_0_assert.sh` has three
arms (`assert_return`, `assert_trap`, `action`) that each
check `if 'module' in a:` and emit
`skip-adr-skip_cross_module_action <kind> on module={mod}
field={fn}`. The pre-d-60 vocab was
`skip-adr-cross-module-action` (no `skip_` infix); d-60
renamed it to the gate-conforming
`skip-adr-skip_cross_module_action` form so this ADR's
filename matches what `check_skip_adrs.sh` expects.

## References

- ADR-0029 (Path B `skip-impl == 0` enforcement + prefix-vocab
  rule)
- ADR-0050 D-2 (skip-ADR effectiveness gate)
- ADR-0057 (`spec_assert_runner_non_simd` factoring)
- D-079 (cross-module imports umbrella)
- D-082 (Path B vocab migration; D-072 (c)-path follow-up)
- D-105 (memory_grow cross-module memory imports — sub-case)
- D-126 (`bulk.wast` post-mutation funcptr divergence — sub-case)
- D-131 (prefix-vocab gate cleanup — this ADR + paired
  `skip_host_state_diverged.md` discharge that row)
- [`skip_cross_module_register.md`](skip_cross_module_register.md) —
  the paired `(register ...)` directive skip-ADR
- Wasm spec §A.1 (wast syntax for `register` + cross-module
  actions)
