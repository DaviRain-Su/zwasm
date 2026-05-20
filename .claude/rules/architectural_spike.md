---
paths:
  - "src/**/*.zig"
  - "build.zig"
  - ".dev/decisions/**"
---

# Architectural spike discipline

Auto-loaded when editing Zig source / build / ADRs. Codifies
close-plan §6 (d) (resolving A3 — "helper先 land → wire-up 別
cycle" was operating as an on-branch spike). Sibling to
[`spike_lifecycle.md`](spike_lifecycle.md) (which governs
`private/spikes/<slug>/` Status) and
[`no_workaround.md`](no_workaround.md) (which forbids indefinite
workarounds).

## The rule

A code commit on `zwasm-from-scratch` MUST have an **observable
behaviour point** that exercises the diff. Forbidden shape:

- Add a helper / type / shape / signature change to `src/` and
  defer the call-site wire-up to a later cycle.
- "Preparatory infra" / "lay the groundwork for" / "wire up
  next chunk" commits that change `src/` without a test, spec
  fixture, or existing caller already exercising the new path.

If the design needs experimentation before commitment, the
experiment belongs in `private/spikes/<slug>/` (gitignored;
governed by `spike_lifecycle.md`), NOT on `zwasm-from-scratch`.

## Observable behaviour points (≥ 1 required per commit)

A diff to `src/` qualifies as "observed" when one of the
following holds in the same commit:

1. A new or updated test under `test/` exercises the changed
   code path and is green.
2. An existing spec fixture covers the new path (cite the
   fixture in the commit body).
3. The diff is a pure rename / signature unification where the
   caller-side update is in the same commit AND the existing
   test suite already covers the path.
4. Behaviour-neutral refactor: AST-equivalent transform whose
   neutrality is asserted by the test gate (test-all green
   pre & post).

If none of (1)–(4) holds, the diff is an on-branch spike. Move
to `private/spikes/`.

## Why (motivation)

D-153 (close-plan A3 / B3): 12 cycles of "preparatory infra"
commits (B146–B158) landed catalog + predicate + validator
shape changes onto `zwasm-from-scratch` without ever flipping
the SKIP-CROSS-MODULE-IMPORTS count. B156 attempted the wire-up
flip → 6 regressions → reverted. The infra was structurally
correct but unobservable until the flip; the flip exposed an
unrelated shape bug (validator_globals prefix) only fixable by
re-walking the design.

The structural lesson: **on-branch spike work is the worst kind
of spike** — it carries the cost of green-gate maintenance (test
gate, lint gate, file-size cap) but produces zero behaviour
delta. The same experimentation in `private/spikes/d153/`
would have surfaced the validator_globals shape bug at hour 1
of the spike, not at cycle 12 of "preparatory infra".

## Cross-reference with the LOOP

[`LOOP.md` §"Chunk types"](../../skills/continue/LOOP.md) defines
`architectural`-typed chunks and the 3-cycle measurable-progress
cap. This rule is the **commit-time** discipline that supports
that cap: if an `architectural` chunk's diff has no observable
behaviour point, it's already in spike territory and the
cycle-counter should not reset.

## Audit hook

`audit_scaffolding §G.5` runs:

```sh
bash scripts/audit_arch_spike_pattern.sh
```

The script greps recent commits (last 14 days) on
`zwasm-from-scratch` for forbidden phrases ("preparatory infra",
"wire-up next cycle", "helper for the next chunk", etc.) and
reports any commit whose body lacks a paired ADR or
`private/spikes/<slug>/` reference. Surfaced commits get
`soon` findings (the spike pattern is in-flight); commits
without the safety pairing get `block` (re-derives D-153).

## Forbidden phrases in commit messages

- `preparatory infra` (use `private/spikes/`)
- `wire-up next cycle` (the wire-up belongs in the same cycle
  OR the helper belongs in `private/spikes/`)
- `helper for <future>` without a same-cycle caller
- `lay the groundwork for` without a same-cycle test

The forbidden list mirrors `no_workaround.md`'s commit-phrase
section. If you find yourself reaching for one of these phrases,
the diff belongs in a spike directory.

## When this rule does NOT fire

- Test infrastructure changes (e.g. adding fixture loader,
  spec runner helpers) — these are observable by virtue of
  existing tests passing differently or new tests landing
  in the same commit.
- Schema / ADR amendments under `.dev/` — docs-only diffs are
  exempt (no src/ change to observe).
- Pure data files (e.g. spectest catalog YAML) when paired
  with a same-cycle test/runner that consumes the data.
- Build system additions (`build.zig`) where the build target
  is exercised by the test gate.

## Stale-ness

If `private/spikes/` is unused for > 90 days OR if
`audit_arch_spike_pattern.sh` flags no commits for > 60 days,
the rule is either dormant (good — discipline holds) or
silently bypassed (bad — phrases drifted around the grep).
Re-check the forbidden phrase list against `git log
--since="60 days ago"` to catch new euphemisms.

## Related

- `spike_lifecycle.md` — Status discipline for
  `private/spikes/<slug>/` (running / merged-into-prod /
  rejected / archived).
- `no_workaround.md` — sibling rule for runtime workarounds.
- `extended_challenge.md` Step 4 — spike as a tool for
  mid-cycle verification.
- `.dev/lessons/2026-05-20-refactor-tradeoffs-honest-accounting.md`
  — the D-153 / B146–B158 retrospective that motivated this
  rule.
- `.dev/phase9_structural_debt_close_plan.md` §6 (d) — the
  close-plan step that ordered this rule's creation.
