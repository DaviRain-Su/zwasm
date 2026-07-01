Loaded on demand from `.claude/rules/textbook_survey.md`; not auto-loaded.

# Textbook survey — guards, skip rules, v1 monolith trap

This file holds the full anti-pull guardrails, skip-condition logic, and
the v1-monolith-file trap discipline. The gate-rule preserves the
reference table + brief survey procedure.

## Survey procedure (default brief for Explore subagent)

```
Survey how <CONCEPT> is implemented in:
  - ~/Documents/MyProducts/zwasm  (v1) — read, never copy
  - ~/Documents/OSS/<relevant>    (industry references)

Return 200–400 lines:
  - Files & line ranges where the concept lives
  - Key data shapes (types, fields)
  - Idioms used (Zig 0.16 / Rust / Go / etc.)
  - Differences across the sources, with one-line "why each chose this"
  - 2–3 places where zwasm v2 should likely DIVERGE based on
    ROADMAP §2 principles (especially P3 cold-start, P6 single-pass,
    P7 backend parity, P10 no-copy-from-v1, A2 file-size cap, A12
    dispatch-table-not-pervasive-if).

Do NOT copy code. Describe the design space.
```

The summary lands in `private/notes/<phase>-<task>-survey.md`
(gitignored, optional).

## Anti-pull guardrails

A survey is a hazard: reading 10 000+ LOC of v1 makes it tempting to
copy patterns wholesale. To prevent this:

### Guard 1 — Cite ROADMAP principles before adopting a v1 idiom

For each idiom you import from v1, write one line:

> Adopting v1 `<idiom>` because ROADMAP P# / A# / §N.M aligns with it.

If you can't write that line, the idiom is folklore — re-derive from
ROADMAP first.

### Guard 2 — Always note one DIVERGENCE

Step 0's deliverable must include "where zwasm v2 diverges from all
references". If it doesn't, the survey was too shallow or the concept
is mechanical (in which case Step 0 should have been skipped).

### Guard 3 — Forbidden patterns are forbidden even if v1 uses them

ROADMAP §14 lists patterns to reject regardless of textbook precedent.
v1 had `std.Thread.Mutex` / `std.io.AnyWriter` / `pub var` vtables in
places — they are forbidden in v2.

### Guard 4 — W54-class lessons are mandatory inputs

When the task touches regalloc / reg_class / per-arch emit / post-
regalloc IR shape, the survey **must** cite the W54 post-mortem
(`~/Documents/MyProducts/zwasm/.dev/archive/w54-redesign-postmortem.md`)
and `~/zwasm/private/v2-investigation/notes/v1-audit.md` § "Implicit
Contract Sprawl". Skipping these for those tasks is a guard violation.

### Guard 5 — No copy-paste

The act of typing every line is the act of re-deciding. Even when the
result happens to match v1 exactly, the line is yours, not v1's. See
`.claude/rules/no_copy_from_v1.md`.

## When to skip Step 0

Skip only when **all** of the below are true:

- The task is a refactor / rename / doc-only change, **OR** an
  environment / scaffolding verification (Phase 0 build-host smokes,
  hook wiring, CI matrix opening — no "concept" to survey).
- AND no new public API is introduced.
- AND implementation does not change behaviour observable from outside
  the module.

If any is false, do Step 0 even if "you already know how v1 did it" —
the survey output guides the per-task structure.

### "Continuation of prior task" — narrow definition

The `/continue` skill's Step 0 description allows skipping when the
task is "clearly a continuation of a prior task". This phrase has a
**narrow** meaning that the loop has historically over-extended.
Concretely, "continuation" means:

- Same handler shape with **only** a different encoder thunk
  (e.g. f32x4.add → f32x4.sub: same `emitV128Binop(encoder)` shape,
  swap the encoder argument). The encoder itself was already designed
  in the prior chunk's survey.
- Diff adds **zero** new encoder functions.
- Diff adds **zero** new helper functions.
- No new design choice (scratch-reg reservation, multi-instr synthesis
  pattern, const-pool plumbing, etc.) is introduced.

If the chunk introduces **any** of:

- A new NEON / SSE / GPR encoder (`encXxx` function),
- A new shared helper in `op_simd.zig` / `op_alu_*.zig` / etc.,
- A new scratch-register reservation,
- A multi-instruction synthesis pattern,
- A const-pool / data-pool entry,
- Cross-cutting infrastructure (regalloc walker entry beyond a single
  `.@"..."` arm — e.g. shape_tags semantics change),

…then Step 0 is **mandatory**, even if the parent ROADMAP row already
had Step 0 run for an earlier sibling sub-chunk.

**Concrete examples (from §9.6):**

| Sub-chunk | Step 0 status | Reason |
|---|---|---|
| 9.6-a (FADD/FSUB/FMUL/FDIV)    | Should have run | New encoder family even though same handler shape as 9.5-c-iv |
| 9.6-b (FABS/FNEG/FSQRT/FRINT*) | Should have run | New encoder family + new `emitV128Unop` helper |
| 9.6-c-i (FMIN/FMAX)            | Could skip      | Same encoder family as 9.6-a (three-same), reuse helper |
| 9.6-c-ii (pmin/pmax synthesis) | Should have run | New synthesis pattern + V31 scratch-reg first-use |
| 9.6-d (int compares)           | Should have run | New encoder family + 2 new helpers |
| 9.6-e (FP compares)            | Could skip      | Reuses 9.6-d helpers, only 4 new encoders in same family |
| 9.6-f-i (TBL 1-reg)            | Should have run | Brand new instruction class |
| 9.6-f-ii (TBL 2-reg, shuffle)  | Should have run | Consecutive-reg constraint + const-pool |

The "could skip" cases are still strictly "should have run" — the
tablebookcase is harmless (10 minutes for an Explore subagent) compared
to a wrong-shape design landing without seeing how cranelift / zware
handle the same op family.

### Trap: v1 monolith files vs name-suggested split

v1 zwasm uses a **monolith convention** for codegen: `jit.zig`
(~8.7k LOC) and `x86.zig` (~7.5k LOC) carry scalar AND SIMD AND support
code together. Topic-named files like `simd_arm64.zig` / `simd_x86.zig`
may exist as **15-LOC aspirational stubs** marked
`return false; // No opcodes implemented yet` — placeholders for future
extraction, NOT signals that the feature is unimplemented.

v2's split discipline (per-op-family files, §A2 hard-cap regulated) is
the OPPOSITE convention; v2 file names DO reflect content. Do not
transplant v2's expectation onto v1 reads.

**Survey discipline for v1 reads**:

1. Always grep the whole `~/Documents/MyProducts/zwasm/src/` tree for
   op references / encoder fn names BEFORE concluding a feature is
   unimplemented:
   ```sh
   grep -rE "(<op-keyword>|enc[A-Z]|emit[A-Z])" ~/Documents/MyProducts/zwasm/src/
   wc -l ~/Documents/MyProducts/zwasm/src/{jit,x86}.zig
   ```
2. 15-LOC topic file with a "placeholder" comment ⇒ assume the monolith
   holds the impl. Trust 1000+ LOC files to reflect their boundary.
3. Cross-check `testdata/conformance/` for fixtures and
   `.dev/decisions.md` for strategy notes — e.g. v1 D122 names the SIMD
   JIT strategy as "predecoded IR + deferred NEON", which explicitly
   tells you SIMD impl exists somewhere even if not in the topic-named
   file.

Worked example: lesson `2026-05-09-v1-monolith-file-survey-miss.md`
records a concrete misread of v1 SIMD as "zero implementation" that
was corrected only when the user pushed back. Avoid replaying it.

### Mid-cycle correction

If you discover mid-implementation that you skipped Step 0 when you
shouldn't have, the correction is: dispatch the Explore subagent
**now**, even if you've already written code. The survey informs the
**refactor pass** (Step 4) — if it surfaces a better design, apply
behaviour-preserving simplification per Step 4 discipline. Worst-case
the survey confirms the spec-derived shape was correct, and the cost
is just the subagent time.
