# 0070 — libc dependency policy

- **Status**: Proposed
- **Date**: 2026-05-19
- **Author**: continue loop §9.12 substrate audit cycle
- **Tags**: phase-9, libc, dependency-boundary, posix, hygiene

> **Status**: skeleton. Will be expanded into the full draft during §9.12-pre.

## Context

Issues identified by the Phase 9 completion substrate audit (ADR-0062 §9.12 Q6):
- v2 uses `sigsetjmp` / `siglongjmp` via libc for signal recovery
- `std.c.*` calls are scattered across multiple sites (`std.c.write` / `_exit` /
  `getenv` / `munmap` and similar; <100 sites)
- The Zig 0.16 stdlib is progressing in a buildable-without-libc direction
- libc dependencies will become a boundary problem for AOT (Phase 12) /
  Windows-native (Phase 13+)

Details: `.dev/phase9_completion_substrate_audit.md` §Q6.

## Decision

Classify `std.c.*` calls into 3 categories; new calls cannot be added without an ADR amendment.

### Categories

| Category | Examples | Treatment |
|---|---|---|
| **necessary** | `sigsetjmp` / `siglongjmp` (not available in Zig stdlib); `pthread_jit_write_protect_np` (Darwin W^X) | Retain; wait for Zig stdlib additions (Issue link required) |
| **replaceable** | `std.c.write` / `_exit` / `getenv` / `munmap` and similar | Migrate to `std.posix.*` / `process.Environ` |
| **convenience** | `std.heap.DebugAllocator` (Debug build) | Permitted in Debug build only |

### Enforcement

- `.claude/rules/libc_boundary.md` auto-load on `src/**/*.zig` (rule)
- `scripts/check_libc_boundary.sh` (detects new std.c.* additions + grep against category classifications)
- Extend `audit_scaffolding §G.5`
- ROADMAP §14 forbidden list amendment: "Unconscious libc fanout"

### Sample migration

In §9.12-D, migrate ~5-10 sites of `std.c.{write,_exit,getenv,munmap}` to `std.posix.*`
(proof that the rule has teeth).

## Alternatives considered

> Skeleton — to be expanded in §9.12-pre.

## Consequences

- **Positive**: Easier to free from libc on AOT / Windows / future embedded targets
- **Negative**: Requires phased migration of ~100 existing sites (as a D-NNN sweep)
- **Neutral / follow-ups**: Track items in the necessary category via Zig stdlib upstream PRs

## References

- ROADMAP §14 (forbidden list amendment), §11 layers
- ADR-0067 (ubuntunote host pivot; D-134 Rosetta) — one of the origins of libc reliability issues
- ADR-0071 (Phase 9 substrate audit resolution; one of the Q6 deliverables)
- `.dev/phase9_completion_substrate_audit.md` §Q6

## Revision history

| Date       | SHA          | Note                                                          |
|------------|--------------|---------------------------------------------------------------|
| 2026-05-19 | `<backfill>` | Initial skeleton — Q6 deliverable; full draft in §9.12-pre.   |
