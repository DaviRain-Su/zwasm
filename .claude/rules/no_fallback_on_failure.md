---
description: "Anti-fallback / anti-silent-degradation discipline for Phase 9 completeness substrate. Errors must propagate as named errors or be handled by exhaustive switch with ADR-justified rationale; silent skip / default-on-failure / try-simpler-path patterns are forbidden."
paths:
  - "src/**/*.zig"
  - "test/spec/spec_assert_runner_base.zig"
  - "test/spec/spec_assert_runner_non_simd.zig"
---

# Anti-fallback / anti-silent-degradation

> **Status**: skeleton (2026-05-19). To be completed during the §9.12-A
> enforcement-layer construction phase.
> This file lands as the skeleton of the "mechanical enforcement layer
> for not giving up" (master plan §7 / §7.4) in the context of the
> §18.2 ADR-first requirement, alongside ADR-0071 + ADR-0073 + ADR-0050 amend.

## The rule

Forbid patterns in error handling that constitute **silent degradation**.
Specifically:

- `catch \|err\| return null` (returns false information to the caller)
- `catch \|err\| .default_value` (silently demotes the intended semantics)
- `catch \|err\| switch (err) { else => continue }` (= "ignore unknown errors")
- `catch {}` (= complete silence)
- Adding new code that emits `SKIP-*` tokens at runtime (= overwriting a give-up path)

Alternatives:

- Propagate the error type as a named error union (`!void` / `!T`)
- Exhaustive switch (`switch (err) { error.X => ..., error.Y => ... }`) —
  only when justified by an ADR
- Trap-class errors must be observable as a trap per the spec, so
  propagate them via `Error.Trap` etc.
- "Re-throw unknown errors" (`switch (err) { else => |e| return e }`)

## Why

Bugs in the D-026 / D-082 family (silent skip where the damage is found
only later) surfaced repeatedly on the way to Phase 9 completeness. The
primary exit criterion of Phase 9 completeness is "skip-impl == 0"
(§9.12-E), and a single silent fallback anywhere collapses that exit.

## Enforcement

- `scripts/check_fallback_patterns.sh` (to be implemented in §9.12-A):
  grep-based detection
- `audit_scaffolding §G.6` (to land in §9.12-A)
- ADR-0050 D-5 (skip-impl one-way ratchet): any increase in runtime SKIP-*
  requires an ADR

## Exceptions

Fallbacks justified by an ADR are allowed. Example:
- The skip-adr-* prefix justified by ADR-0029 (skip-impl vs skip-adr
  semantics) (= deliberate skips that are spec-wise out of scope for v2)

## Stale-ness

The grep patterns in `scripts/check_fallback_patterns.sh` may become
false-positive-prone if the signatures of the functions detected by the
grep change. Liveness is verified by `audit_scaffolding §G.6`.

## Related

- ADR-0050 amend (D-5 / D-6 skip-impl one-way ratchet)
- ADR-0071 §Q3 (Phase 9 completeness substrate audit resolution)
- Master plan §7.4
- `.claude/rules/no_workaround.md` (sibling rule; SKIP-* increase
  prohibition wording)
- `.claude/rules/extended_challenge.md` Step 4 (spike-driven alternative
  exploration)
