---
description: "Spike lifecycle discipline — Status management for private/spikes/<slug>/ + mandatory lesson when rejected/archived + audit flag when running >14d. Extracted and reinforced from `extended_challenge.md` Step 4."
paths:
  - "private/spikes/**/README.md"
  - ".dev/lessons/**"
---

# Spike lifecycle

> **Status**: skeleton (2026-05-19). Completed in the §9.12-A enforcement layer.

## The rule

A `private/spikes/<slug>/` directory **MUST have a lifecycle Status**:

| Status | Meaning |
|---|---|
| `running` | In progress. Maximum 14 days (audit flag) |
| `merged-into-prod` | Folded into the production implementation. Production commit SHA required |
| `rejected` | Not adopted. Conclusion MUST be recorded in `.dev/lessons/YYYY-MM-DD-<slug>-rejected.md` |
| `archived` | Past rejection; spike dir remains but no activity |

Each spike's README.md MUST declare its Status explicitly in the frontmatter or at the top:

```markdown
# spike: q3-zig-inline-switch

**Status**: running
**Started**: 2026-05-19
**Outcome**: <TBD>
**Hypothesis**: Does a 581-tag `inline switch` hit a Zig 0.16 compile-time wall?
```

## Why

In the D-134 (Rosetta heisenbug) investigation, if the 5 cycles of hypothesis
rejection had not been recorded, root-cause identification at cycle 6 would
not have been possible. If a spike is discarded without a record, future-you
or the next session pays the same trial cost again.

The "spare no effort" discipline is not about "attempting experiments" but
about "recording experimental results".

## Enforcement

- `scripts/audit_spikes.sh` (existing; lifecycle check reinforced in §9.12-A)
- `audit_scaffolding §G.4` (existing; verifies that the reject lesson has landed)
- running > 14d produces a `soon` audit finding
- rejected w/o lesson produces a `block` audit finding

## Migration to lesson on reject

```
1. In the spike dir, record `Status: rejected` + Outcome
2. Land `.dev/lessons/YYYY-MM-DD-<spike-slug>-rejected.md`
   - Carefully cover: what was tried / why it was rejected / what was learned
3. Move the spike dir to `private/spikes/archive/<slug>/` (optional)
4. State the rejection explicitly in the commit message
```

## Related

- ADR-0071 §Q3 (3 spikes adopted: q3-zig-inline-switch / q3-interp-dispatch-bench /
  q3-build-option-dce-poc)
- Master plan §7.5
- `.claude/rules/extended_challenge.md` Step 4 (spike-driven alternative exploration)
- `.claude/rules/lessons_vs_adr.md`
