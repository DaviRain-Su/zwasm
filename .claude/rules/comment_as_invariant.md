---
description: "Forbid prose-only invariant comments. Pair invariants with a comptime/runtime assert or a lint check (D-132/D-133 failure mode)."
paths:
  - "src/**/*.zig"
---

# Comment-as-invariant (stub per ADR-0118 D2)

Source-comment invariants ("X10/X11/X12 are private scratch") MUST be
paired with `std.debug.assert` / `comptime`-asserted named-constant OR
caught by lint. Prose-only invariants are the D-132/D-133 failure mode.

**Mechanization**: `bash scripts/check_invariant_comments.sh` greps for
hardcoded register numerals in `encStrXRegLsl3` / `encLdrImm` etc. + the
prose-comment patterns it covers.

**Why**: ADR-0072 (full rationale + D-132/133 case study + naming
patterns). Lesson `2026-05-16-regalloc-pool-scratch-overlap.md` for the
discovery.
