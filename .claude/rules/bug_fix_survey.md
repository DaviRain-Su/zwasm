---
paths:
  - "src/**/*.zig"
  - "build.zig"
---

# Bug-fix-time survey: grep siblings before changing code

Auto-loaded when editing Zig source. Codifies the "twin-largest"
regret from the 2026-05-04 retrospective: bug fixes have historically
jumped from symptom → diff without checking whether the same shape
exists elsewhere — landing the fix at the symptom, not the
population.

## The rule

Before editing code to fix a bug, run a **same-class-cases survey**:

1. Identify the symptom's **shape** (a symbol, control-flow pattern,
   type, opcode group, field-merge logic).
2. **Grep** the codebase for that shape (`rg -n '<symbol>' src/` and
   a shape-level regex when the symbol is too narrow).
3. Apply the fix at every site where the shape recurs, OR document
   why a site is exempt.
4. If the symbol is **near a ROADMAP §14 entry** (single slot dual
   meaning, ARM64-only feature, dispatch-table bypass), re-read the
   §14 entry + corresponding `.claude/rules/*.md` before editing.

This complements `textbook_survey.md` (task-start design survey) by
addressing **bug-fix-time** survey discipline.

## When to skip (gate)

- **Trivial fixes**: typos in comments, format strings, missing
  `null` check on a single optional with unambiguous source.
- **Type-system errors**: compiler enumerates every site needing
  change; manual grep is redundant.
- **Refactor-rename bugs**: `replace_all` covers the population.

If unsure: run the grep. 30 seconds vs one re-fix cycle.

## Why this rule exists (short)

Case study D-027: the if-result merge fix in sub-7.5c-vi landed for
`if` only; `block (result T)` and `loop (result T)` needed the same
fix and burned an extra cycle in sub-7.5c-vii. A bug-fix-time grep
for "label result arity" would have surfaced both siblings before
the first commit.

詳細(full procedure with rg examples, additional case studies,
reviewer checklist, rule-interaction table, anti-patterns) は
[`references/bug_fix_grep_procedure.md`](../references/bug_fix_grep_procedure.md)
を参照。
