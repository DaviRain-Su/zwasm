---
description: "Cat III runtime/instance/store/linker layer zone-rule + hygiene anchor. Prevents invariant comments / silent fallback / cross-zone imports when editing `src/runtime/instance/` + `src/api/instance.zig`."
paths:
  - "src/runtime/instance/**/*.zig"
  - "src/runtime/store.zig"
  - "src/runtime/runtime.zig"
  - "src/api/instance.zig"
  - "src/api/cross_module.zig"
---

# Runtime / instance / store / linker layer hygiene

> **Status**: skeleton (2026-05-19). Justified by ADR-0071 §Q5
> (Cat III hygiene anchor). Completed in §9.12-C.

## The rule

In Phase 9 §9.9-III, Cat III code (Wasm 1.0 instance / store / linker /
cross-module / host-imports / start-trap) landed. This layer observes
the following discipline:

### Zone direction

- `src/runtime/instance/*.zig` is **Zone 2 = runtime**
- Import direction: `runtime/instance/` → `runtime/`, `ir/`, `parse/`, `support/`, `support/platform/` (= Zone 0-2 only)
- Forbidden: `runtime/instance/` → `engine/codegen/*` (Zone 3); `cli/*` (= UI Zone)
- Details: `.claude/rules/zone_deps.md`

### Invariant comments

`.claude/rules/comment_as_invariant.md` applies. Prose-only comments of
the "X is always Y" form are forbidden (enforce via comptime/runtime
assert OR delete).

### Silent fallback

`.claude/rules/no_fallback_on_failure.md` applies. Do not swallow linker
errors with patterns like `catch \|err\| return null`. Propagate
`Error.UnknownImport` / `Error.ImportTypeMismatch` etc. as named errors.

### Cross-module state management

- Register to the session-local registry via `Store.register(name, *Instance)`
- Lookup via type-check using `Instance.findExport(name, kind, sig)`
- Dispatch via bridge thunks using `resolveCrossModuleImports()`
- Extensions to these functions must be justified in an ADR (D-079 / D-102 /
  D-103 / D-105 cohort discharge is in §9.12-E)

## Why

Cat III code includes rushed implementations from §9.9-III, and is the
target of the Phase 9 complete substrate audit Q5 hygiene anchor. This
rule auto-loads the hygiene discipline to deter new edits from
reproducing the same failure modes (Pointer 0xAA poisoning / X19
corruption / etc.).

## Enforcement

- This rule auto-loads on the listed paths
- The D-132 / D-133 grep extensions in `audit_scaffolding §G` also apply
  to runtime/instance/
- `bash scripts/zone_check.sh --gate` detects zone violations (transition
  to enforce mode in §9.12-G)

## Related

- ADR-0066 (cross-module import bridge thunks)
- ADR-0068 (dual-view table storage fix)
- ADR-0071 §Q5 (Phase 9 complete hygiene resolution)
- D-079 / D-102 / D-103 / D-105 (Cat III tail debt; discharged in §9.12-E)
- `.dev/lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md`
- `.dev/lessons/2026-05-17-gamma3d-dispatch-write-segv-bisect.md`
