---
paths:
  - "src/**/*.zig"
  - "build.zig"
---

# No-workaround rule

Auto-loaded when editing Zig source. Codifies a v1 lesson that drove
this redesign.

## Three principles (from ROADMAP §P1 / §P3 / §P14)

1. **Fix root causes, never work around.** Missing feature?
   Implement it first. Spec gap? File a ROADMAP §9.<N+1> task; do
   not paper over.
2. **Spec fidelity over expedience.** Never simplify the API or the
   IR to avoid a gap. The Wasm spec is ground truth (P1).
3. **Defer rather than work around.** If a feature is genuinely not
   ready for the current phase, place it in a later phase and add
   a `// TODO(p<N>): <one line>` comment with the phase number.
   Never embed an indefinite workaround.

## Forbidden phrases in commit messages

- `quick fix` — escalate to root cause or ADR-document the limitation.
- `temporarily skip` — spec test skip=0 is a release gate (A10).
- `disable for now` — disable forever or fix; avoid the third option.
- `workaround for <upstream>` without an ADR reference.

## When a workaround is genuinely needed (gate bar)

Sometimes the upstream is broken. The bar:

1. ADR documents the workaround with upstream issue link, expected
   expiry condition, and removal plan.
2. Workaround is contained in one file (`src/platform/` for OS quirks,
   `src/util/` for stdlib gaps).
3. A `// TODO(adr-NNNN): remove once <condition>` comment marks it.
4. `audit_scaffolding`'s "lies" check periodically verifies the
   removal condition still hasn't fired.

詳細(v1 anti-patterns D116/W54/D117, spike boundary, reviewer
checklist) は
[`references/no_workaround_details.md`](../references/no_workaround_details.md)
を参照。

## Sibling rules

- [`architectural_spike.md`](architectural_spike.md) — forbids
  on-branch architectural spikes ("helper先 land → wire-up 別
  cycle" pattern that caused D-153's 12-cycle drift). Code
  commits to `zwasm-from-scratch` must have an observable
  behaviour point; experimentation belongs in
  `private/spikes/`.
- [`spike_lifecycle.md`](spike_lifecycle.md) — Status
  discipline for `private/spikes/<slug>/`.
