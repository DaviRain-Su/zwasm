# 0153 — Structural rework campaign mode + correctness-assured optimization discipline

- **Status**: Proposed (2026-06-04; user-directed instruction-system change — pending user review per "止めて待受け")
- **Date**: 2026-06-04
- **Author**: claude (instruction-system rewrite, user-directed)
- **Tags**: meta, loop, instruction-system, regalloc, perf, correctness, ADR-0118, ADR-0132, design-priority
- **Amends**: `.claude/skills/continue/SKILL.md` (+ new `REWORK.md`); `.claude/skills/continue/LOOP.md`
  (architectural chunk cross-ref); ROADMAP §1.2 (parity-miss → scheduled rework note); CLAUDE.md (design-priority
  pointer). Sits ABOVE the `architectural` chunk type + bundle mode — a multi-bundle campaign structure.

## Context

The §15.P parity measurement (D-263 → D-265) surfaced that a **deliberate v2 simplification** — the
deterministic-slot / spill-everything single-pass regalloc (ADR-0149/0150, chosen Phase 7-8 to avoid v1's
W54-class regalloc bugs) — is **~2.3× slower than v1** whenever a loop body reads a loop-carried local (array
indexing, counters). Compute/SIMD is at-parity-or-faster; the gap is specific + structural.

Two things this exposed about the loop's instruction-system:

1. **The design priority was implicit.** The user made it explicit (2026-06-04, recorded in memory
   `feedback_design_priority_completeness_over_v010`): zwasm v2's bar is **clean final design + full-featured +
   100% spec + lightweight-yet-fast**; **a measured violation of one of those dimensions schedules a rework even
   if the blast radius is large; v0.1.0 is not urgent.** D-265 is a literal **v0.1.0 parity-line miss** (§1.2 =
   "parity with v1") → it is in-scope, not a post-v0.1.0 defer.

2. **The loop had no structured mode for a large, correctness-critical rework.** It has `emit`/`architectural`/
   `survey`/`infrastructure` chunk types + bundle mode (multi-cycle integration) + the `architectural` 3-cycle
   cap. But a cross-layer redesign of a hot, correctness-critical path (here: ZIR-lowering + liveness + regalloc +
   both emit backends) needs more than ad-hoc bundles: a deep **investigation** phase, a **correctness-assurance-
   first** gate (pin current correct behaviour with characterization + adversarial tests BEFORE touching the
   design), and explicit **retrospective** checkpoints. The D-265 investigation this session did all of this
   AD HOC across 4 cycles; the discipline should be first-class so the next rework (and there will be more —
   D-261 GC-rooting, ADR-0136 WASI-under-JIT) is done safely by default.

## Decision

**1. Adopt the design priority (sharpened).** Per `feedback_design_priority_completeness_over_v010` + ROADMAP §1.2
(parity) + §1.4 (lightweight-fast) + P14 (optimisation in Phase 15): a **measured** structural deficiency in a
完成形 dimension — especially a v1-parity miss — **defaults to "schedule a rework campaign," not "defer past
v0.1.0."** v0.1.0 timing never gates the rework decision; correctness + design quality do. (This does NOT loosen
P1 spec-fidelity or P3/P6 single-pass — see constraint below.)

**2. Reworks operate WITHIN the inviolable principles.** P3 + P6 mandate single-pass (Decode → ZIR → regalloc →
emit; no SSA / multi-pass IR optimisation); §1.3 + §3.2 put a multi-tier optimising JIT permanently post-v0.1.0.
So a rework improves the **single-pass baseline** (e.g. a better single-pass register allocator that keeps hot
locals register-resident, as v1 does — also single-pass), NEVER adds an optimisation tier. A rework that would
require violating P3/P6 is out of scope and must stop for a P-level ADR + user decision.

**3. Add a structural-rework campaign mode** (`.claude/skills/continue/REWORK.md`), a multi-bundle structure with
five ordered phases, the first two of which are **hard gates** before any redesign code lands:
  - **I — Investigation** (調査): deep, multi-angle root-cause to a *confirmed mechanism* (not inference) + ROI
    ceiling *measured* + cross-layer blast-radius mapped + candidate approaches with cost/risk. Output = a written
    findings doc. (D-265's `bench/results/s15p_parity_vs_v1.md` is the template.)
  - **II — Correctness assurance FIRST** (正しさ担保): BEFORE touching the design, pin the current correct
    behaviour of the area being reworked with characterization + **adversarial** tests (differential vs
    interp/v1, the specific failure modes the new design risks) so the rework cannot silently regress. This is the
    hard gate the user named ("十分に担保した上での最適化"). Directly addresses the D-261-class risk (reworking an
    area that has no adversarial test).
  - **III — Design** (設計): an ADR for the new single-pass architecture, listing the invariants that prevent
    regressing to the old bugs (cite the lessons, e.g. W54 / regalloc-pool-scratch-overlap), the cross-layer
    touch-points, an incremental behaviour-preserving migration path, and the measurable exit (ROI recovery +
    green test net). Spike off-branch first if the approach is unproven (spike_discipline).
  - **IV — Implementation** (実装): behaviour-preserving TDD steps, **the full test net green at EVERY commit**
    (correctness is non-negotiable — this is *assured-correctness* optimisation), perf measured at milestones (the
    ROI target is a gate). Bundle mode for continuity; the architectural 3-cycle cap still forces a step-back.
  - **V — Retrospective** (振り返り): at campaign close AND at major milestones — did it hit the 完成形 (measured
    target + clean design)? what NEW risk/debt did the rework introduce? update debt/lessons; add a Revision note
    to the superseded simplification ADR (e.g. ADR-0149/0150). Institutionalises the retrospective that surfaced
    D-261/262/263.

**4. Correctness-first ordering is a HARD invariant.** Phases I + II MUST complete (findings doc + adversarial
test net green) before any Phase IV redesign code. You do not optimise an area you cannot prove you have not
broken. A rework that jumps "found problem → redesign code" is the forbidden anti-pattern.

## Rejected alternatives

- **Defer all big reworks past v0.1.0** — contradicts §1.2 (parity is the v0.1.0 line) + the user's design
  priority. v0.1.0 is not urgent; shipping a known parity miss to hit a date is the wrong trade.
- **Just extend the `architectural` chunk type** — too small a unit; a campaign spans many bundles and needs the
  investigation + correctness + retrospective phase structure, not a single 3-cycle-capped chunk.
- **Make it a `.claude/rules/*.md` auto-loaded rule** — rules fire on file-path globs (invariants); a campaign is
  a workflow MODE, so it belongs as a continue-skill sibling (loaded on demand when a campaign is active),
  parallel to LOOP.md / RESUME.md / GATE.md.

## Consequences

- The loop gains a named, correctness-first mode for large reworks. First user: **D-265** (single-pass
  register-resident-locals). Next candidates: **D-261** (GC-on-JIT adversarial test — itself a Phase-II artifact),
  **ADR-0136** (WASI-under-JIT). These were the orphan-prone structural risks from the 2026-06-04 retrospective.
- A campaign is detected at Resume Step 1c (handover `## Active rework campaign` section) — supersedes ROADMAP
  lookup, parallel to the bundle override (Step 1b).
- No inviolable principle changes; ROADMAP §1.2 gains a clarifying note that a measured parity miss is scheduled
  as a correctness-assured rework (this ADR), within single-pass.
- **Pending user review** (the instruction-system rewrite was directed to stop for review before activation).
