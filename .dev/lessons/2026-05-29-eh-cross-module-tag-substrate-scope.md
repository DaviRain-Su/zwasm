# EH cross-module tag imports: substrate scope (D-192 EH clause)

**Date**: 2026-05-29
**Cycle**: 10.X-D192-register cycle 109 (survey)
**Citing**: `<backfill>` (cycle 109 chore commit)

## What was surveyed

The D-192 register substrate's EH clause: `try_table.1.wasm` imports
`test::e0` (a TAG) + `test::throw` (a func) from `try_table.0` (baked
`register test`). The funcrefs half of D-192 was a small fix
(register-manifest + ref.func global-init). The EH half is a MAJOR,
already-designed (ADR-0114) but UNIMPLEMENTED substrate.

## What was learned (current state — all single-module only)

- **ImportKind enum** (`parse/sections.zig:229`) has func/table/memory/
  global only; `0x04` (tag) is REJECTED at parse (`InvalidFunctype`).
- **Tag exports filtered out at decode** (`sections.zig:606`,
  `if (kind_byte == 4) continue;`) — tag exports never reach
  `exports_storage`, so the runner can't discover/bind them.
- **No `ImportBinding.tag`** (`runtime/instance/import.zig:34`); no
  Linker tag API (`defineTag`/`defineCrossModuleTag`) + no
  `Linker.Payload` tag variant (`zwasm/linker.zig:75`).
- **Runner `.register`** (`spec_assert_runner_wasm_3_0.zig:357`) binds
  memory+func; tag arm absent (and tags are filtered anyway).
- **Tag identity is INDEX-based** (`exception.zig:36` `tag_idx: u32`;
  matched at `interp/mvp.zig:613/733/744` by `==`). Single-module
  throw/catch works by validator-guaranteed in-range index. Cross-
  module throw/catch CANNOT match by index (try_table.0's local idx ≠
  try_table.1's import idx). ADR-0114 D1's `*TagInstance` pointer-
  identity is the designed fix — DEFERRED until now.
- Single-module EH EXECUTES (interp tests pass, `mvp.zig:1160+`); JIT
  throw/throw_ref emit incomplete (`arm64/emit.zig:1172`).

## How to apply (10.E-xmodule-tags bundle plan, per ADR-0114)

Multi-cycle, each cycle moving a STAGE (avoid on-branch-spike):
1. Parser: `ImportKind.tag` + `ImportPayload.tag_typeidx` + un-filter
   tag exports → try_table.1 PARSES past the tag import.
2. `ImportBinding.tag` + instantiate switch arm + checkImportTypeMatches
   for tags + Linker `defineCrossModuleTag` + `Payload.tag_alias` +
   runner `.register` tag arm → try_table.1 INSTANTIATES.
3. Runtime `*TagInstance` (ADR-0114 `tag.zig`) + `rt.tags` storage +
   imported tags resolve to source instance's TagInstance.
4. `Exception.tag_idx` → `*TagInstance`; throw/catch match by pointer
   → cross-module throw/catch MATCHES → corpus asserts pass.
5. JIT throw/throw_ref emit (if corpus needs JIT path).

Note: steps 1-2 are 0-corpus-delta (instantiate works but asserts fail
on tag-identity mismatch until step 4). Frame the bundle so each
cycle's observable is the STAGE move (parse→instantiate→match), not
the corpus count, until step 4.

## Related

- ADR-0114 (Exception Handling design — `*TagInstance` D1).
- `.dev/lessons/2026-05-28-funcrefs-tail-error-classes.md` (the
  funcrefs half of D-192; register substrate proven there).
