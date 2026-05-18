---
description: "libc dependency boundary — `std.c.*` calls are forbidden unless they fall into one of the 3 categories (necessary/replaceable/convenience) defined in ADR-0070. New `std.c.*` additions require an ADR justification."
paths:
  - "src/**/*.zig"
---

# libc dependency boundary

> **Status**: skeleton (2026-05-19). Justified by ADR-0070 (Proposed). Completed in §9.12-D.

## The rule

When adding a new `std.c.*` call site in Zig source, it must fall into one of
the 3 categories defined in ADR-0070:

| Category | Example | Handling |
|---|---|---|
| necessary | `sigsetjmp` / `siglongjmp` / `pthread_jit_write_protect_np` | OK; linking the upstream Zig stdlib issue is recommended |
| replaceable | `std.c.write` / `_exit` / `getenv` / `munmap` | NG — use `std.posix.*` / `process.Environ` |
| convenience | `std.heap.DebugAllocator` (Debug only) | OK only in Debug builds |

If a new site is required, an amendment to ADR-0070 (adding the new site to the necessary category) is mandatory.

## Before writing `std.c.<name>`, check first

- `std.posix.<name>` — whether a POSIX abstraction exists
- `std.Io.<name>` — Zig 0.16's Io abstraction
- `process.Environ` — for retrieving env vars
- The corresponding `std.os.linux.*` / `std.os.darwin.*` syscall wrapper

## Enforcement

- `scripts/check_libc_boundary.sh` (to be implemented in §9.12-D): grep-based
  detection of new std.c.* sites + cross-check against ADR-0070's required categories
- `audit_scaffolding §G.5` extension
- ROADMAP §14 forbidden list "Unconscious libc fanout" (added in §9.12-D)

## Grep-able anti-patterns

```sh
grep -nE 'std\.c\.(write|_exit|getenv|munmap)\b' src/ test/
```

## Related

- ADR-0070 (libc dependency policy; rationale for the 3 categories)
- ADR-0067 (ubuntunote pivot; D-134 Rosetta — origin of libc reliability issues)
- ADR-0071 §Q6 (Phase 9 complete libc boundary resolution)
- Master plan §3.6 / §5.3 §9.12-D
