---
description: "Forbid new std.c.* / @extern(\"c\") / pthread_* call sites outside ADR-0070's 3 categories (necessary/replaceable/convenience)."
paths:
  - "src/**/*.zig"
---

# libc boundary (stub per ADR-0118 D2)

New `std.c.<name>` / `@extern("c")` / `pthread_*` / `sigsetjmp` /
`siglongjmp` / `sys_icache_invalidate` site requires ADR-0070
amendment unless the symbol is already on the `necessary` list.

**Mechanization**: `bash scripts/check_libc_boundary.sh --gate` (FAIL
on any `replaceable` or `unclassified` site).

**Before writing `std.c.<name>`**: check `std.posix.<name>` / `std.Io.<name>`
/ `process.Environ` / `std.os.linux.<name>` first.

**Why**: ADR-0070 (full 3-category classification + 16-site inventory +
reviewer checklist). ROADMAP §14 forbidden list — "Unconscious libc fanout".
