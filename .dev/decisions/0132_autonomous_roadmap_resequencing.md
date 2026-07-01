# 0132 — Autonomous ROADMAP re-sequencing for cross-phase dependencies

- **Status**: Accepted (2026-06-03; user directive)
- **Date**: 2026-06-03
- **Author**: claude (user directive)
- **Tags**: governance, ROADMAP §18, /continue loop, deviation-watch, stop-buckets, phase re-sequencing, autonomy
- **Amends**: `.claude/skills/continue/SKILL.md` (Step 1 deviation-watch),
  `CLAUDE.md` (Frozen loop invariants — §18 amendment), `.claude/references/handover_doc_discipline.md`
  §1 (single user-judgment use), `.claude/skills/continue/STOP_BUCKETS.md` (bucket-3)

## Context

ROADMAP §18 already states (preamble): *"Early-phase planning will inevitably
miss dependencies that only become visible when later phases are implemented.
Correcting such mismatches IS the maintenance work, not an ad-hoc patch."* §18.1
explicitly lists *"an exit criterion or scope row references a feature whose
implementation is scoped to a later phase"* as an **amend-in-place** case, and
§18.2 gives the four-step procedure (edit ROADMAP + open ADR + sync handover +
reference ADR in commit).

Despite that, an **overlay** of loop rules forced a *user-gated stop* whenever a
§9 phase-scope/exit edit was needed:

- `/continue` SKILL Step 1 **deviation-watch**: "Plan touches §9 scope → STOP.
  File ADR per §18.2 FIRST."
- `CLAUDE.md` Frozen invariants: "Deviation in §9 phase scope/exit = file ADR
  FIRST."
- `handover_doc_discipline` §1: "single allowed `user-judgment` use = §18 ADR
  amendment requiring user-flip."

The concrete symptom: the **Phase 10 §10-scope question** (ADR-0128 requires JIT
`skip=0`, but multi-memory's ~458 JIT skips are Phase-14 work → unreachable
in-phase) was surfaced as a recurring "USER-GATED (non-stop)" handover flag for
multiple cycles, waiting for a user decision that §18 already authorises the AI
to make.

**User directive (2026-06-03)**: *"ロードマップで最初にすべての実際の依存関係を
明らかにするのは無理だった。Phase 14 対応が Phase 10 の解消要件に必要なら、そもそも
ロードマップ側を柔軟に組み替えるのを、あなたの判断で自律的にやってよい。最近はあんまり
ユーザー判断で止めてほしくない。"*

## Decision

A **§18.1-class amendment** — re-sequencing or re-scoping the ROADMAP because a
phase's exit/scope references work that genuinely belongs to a later phase — is
an **AUTONOMOUS deviation**. The `/continue` loop does NOT stop for it. The AI:

1. Executes the §18.2 four-step (edit ROADMAP in place + open an ADR recording
   old/new wording + sync `handover.md` + reference the ADR in the commit), then
   **proceeds** — no user-flip, no "ADR FIRST then stop".
2. Re-homes the deferred items to their true phase with explicit forward-refs,
   and updates any close-invariant script.
3. Does **not** emit a recurring "USER-GATED" handover flag for this class.

**Unchanged guardrails.** This carve-out is scoped to roadmap re-sequencing/
re-scoping for cross-phase dependencies. It does NOT relax: §14 forbidden
patterns, §2 P/A principles, §4 architecture/Zone/ZirOp, the no-workaround /
no-silent-fallback rules, or the requirement to file an ADR for genuinely-new
design decisions (§18.1 "add an ADR instead"). Those still get an ADR; but per
the user's "don't stop me for user-judgment" posture, the default is
**autonomous-with-ADR**, surfacing (bucket-2/3 stop) only when the work is
genuinely unresolvable or *structurally* needs the user (credentials, an
external product/policy choice, a destructive irreversible action).

## Consequences

- Loop throughput up; no more multi-cycle user-gated parking of correctable
  roadmap mismatches. Traceability preserved via the mandatory ADR.
- First application: **ADR-0133** (Phase 10 exit re-scope).
- Rule files amended (see Amends). Lesson `feedback_autonomous_roadmap_restructure`
  in auto-memory mirrors this for cross-session recall.
- Risk: an over-eager autonomous re-scope could mask a real gap. Mitigation: the
  ADR + reference-chain audit are mandatory, and re-scoping must FORWARD-REF each
  deferred item to a concrete later-phase row (no silent drop) — a deferred item
  with no named home is a no-workaround violation, not a valid re-scope.
