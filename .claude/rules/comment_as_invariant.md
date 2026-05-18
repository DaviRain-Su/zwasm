---
description: "Forbid prose-only invariant comments (e.g. `Y is X scratch / Y has alignment N / Y is private`). Always pair them with a comptime/runtime assert or a lint check. Prevents the D-132/D-133 failure mode."
paths:
  - "src/**/*.zig"
---

# Comment-as-invariant rule

> **Status**: skeleton (2026-05-19). Justified by ADR-0072 (Proposed). Completed in §9.12-C.

## The rule

When a source comment states an **invariant**, it MUST be paired with one of the following:

(a) `comptime assert` (`std.debug.assert` used in a `comptime` context)
(b) runtime `std.debug.assert`
(c) a lint script (via `audit_scaffolding §G grep`)
(d) removal (= don't write it if it isn't needed)

Violation example (the source of the D-132 / D-133 failure mode):

```zig
// X10 / X11 / X12 are private scratch within the handler (= violation — prose only)
const tmp_a = encXR(10);
const tmp_b = encXR(11);
```

Fixed example:

```zig
// abi.zig:
pub const table_emit_scratch_gprs = [_]u4{ 10, 11, 12 };
comptime {
    for (table_emit_scratch_gprs) |r| {
        std.debug.assert(!abi.allocatable_caller_saved_scratch_gprs[r]);
    }
}

// op_table.zig:
const tmp_a = encXR(abi.table_emit_scratch_gprs[0]);
const tmp_b = encXR(abi.table_emit_scratch_gprs[1]);
```

## Why

The `op_table.zig` comment "X10/X11/X12 are private scratch within the handler"
was a prose-only invariant with no code-level enforcement. Regalloc used the
same slots as allocatable scratch, leading to silent corruption on a specific
corpus + nested-table-op (D-132).

Lesson: `.dev/lessons/2026-05-16-regalloc-pool-scratch-overlap.md`

"Comments are documentation; invariants must be enforced in code" is a pillar
of substrate hygiene.

## Enforcement

- This rule auto-loads on `src/**/*.zig` (so Claude has awareness when editing)
- Strengthen `audit_scaffolding §G` grep (§9.12-C; detect `encStrXRegLsl3` etc.
  + hardcoded register numerals)
- D-133 sweep (§9.12-C): replace remaining sites with named-constant references

## Detection patterns (targets for audit grep)

- `// X[0-9]+ are` prose comments
- `// .*scratch.*private` prose comments
- `encStrXRegLsl3\([0-9]+,` / `encLdrImm\([0-9]+,` (hardcoded register numeral)

## Related

- ADR-0072 (the basis for this rule)
- ADR-0018 (regalloc reserved set; precedent for the comptime check)
- ADR-0071 §Q5 (Phase 9 complete hygiene resolution)
- D-132 / D-133 (failure mode + discharge plan)
- `.dev/lessons/2026-05-16-regalloc-pool-scratch-overlap.md`
