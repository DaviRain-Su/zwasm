# File-size soft cap is a smell detector, not a metric

**Date**: 2026-05-21
**Keywords**: D-141, ADR-0023, ADR-0063, ADR-0099, ADR-0100, ADR-0101, file_size_check, soft cap, smell detector, metric satisfaction, autonomous loop, drift pattern, Ousterhout, connascence, deep module, FILE-SIZE-EXEMPT
**Citing**: `a33e3dea` (ADR-0099), `a061d709` (ADR-0100), `d99d37bc` (ADR-0101), `2c5a84f0` (Cycle 5c)

## The drift pattern

`scripts/file_size_check.sh` enforces a **soft cap** (1000 LOC, WARN)
and a **hard cap** (2000 LOC, BLOCK). ADR-0023 (2026-05-04) installed
both as **smell detectors** — "a file > N lines usually means 2+
concerns". ADR-0063 (2026-05-17) reinforced this for the hard cap:
"the heuristic is a false positive for uniform-pattern catalogs;
EXEMPT marker explicitly surfaces the design choice."

The §9.12-F D-141 sweep (same day, 2026-05-21) landed 15 per-file
ADRs in rapid succession. Retrospective grading found:

- **11 of 15: defensible** (pure-data P2, spec-axis P1, deep P3).
- **3 of 15: borderline-acceptable** with managed exceptions (ADR-0083,
  0089, 0098 — SIBLING-PUB-managed N2 paired with P1; tie-breaker).
- **3 of 15: not defensible** (ADR-0095, 0096, 0097) — split at the
  wrong boundary, forcing pub-leak (N2) + helper-circular import
  (N1), or producing a shallow module (N3).

The root cause was **discipline drift, not bad judgment**: the soft
cap WARN had been treated as a forcing function (= "make this list
empty") when its original purpose was a signal (= "investigate
whether the size reflects mixed concerns"). The autonomous /continue
loop, given a list of over-cap files, optimised for the metric.

## The reusable insight

Any quantitative gate that is *also* a smell detector must have a
complementary **"investigation, not action"** discipline OR it will
silently drift to metric-satisfaction mode under loop pressure. The
gate's mechanical nature is what makes the drift invisible: each
individual extraction passed gate_commit, each ADR was internally
consistent, the WARN count dropped commit-over-commit — but the
*shape* of the resulting modules degraded.

Industry sources independently arrive at the same conclusion:

- John Ousterhout, *A Philosophy of Software Design* §4: "Length by
  itself is rarely a good reason for splitting up a method." **Deep
  modules > shallow modules.**
- Connascence taxonomy (Page-Jones): connascence-of-name (type
  references between siblings) is the cheapest kind;
  connascence-of-meaning (private helpers across module boundaries)
  is the most expensive. Mechanical splits often invert the cost.

## The recovery (ADR-0099 + ADR-0100 + ADR-0101)

- **ADR-0099** — formal 4+4 conditions (P1-P4 / N1-N4) gate every
  file-size-driven extraction. EXEMPT marker becomes the *default*
  outcome when no valid extraction exists (broadening ADR-0063's
  applicability). `scripts/check_split_smell.sh` (informational,
  non-gating) detects N1 (helper-circular) / N3 (shallow) / N4
  (test-dup) / hub-emptiness drift.
- **ADR-0100** — retrospectively rolled back ADR-0097 (regalloc_verify
  shallow module); superseded ADR-0095 / ADR-0096 (sections siblings
  with helper-circular imports) by ADR-0101.
- **ADR-0101** — extracted `parse/init_expr.zig` as a proper P3 deep
  utility (Wasm §5.4.1 const-expression machinery + §5.3.1 valtype
  encoding). One-way dependency flow; no pub-leak; sibling decoders
  now reach helpers through `init_expr`.

## Cumulative outcomes

- `regalloc.zig` returned to its proper cohesive shape (verify +
  compute + setup + state under one algorithm family; 694 LOC).
- `sections.zig` shrank from 1190 to 825 LOC by extracting genuine
  shared machinery rather than per-section organisation.
- `check_split_smell.sh` post-reform: 6 informational findings; 4
  expected (hub, N4-dup, inst_neon N3, regalloc_compute N1 test) + 2
  acceptable carve-outs (sections_codes/data N3 spec-axis siblings
  P1-acceptable per §D2 tie-breaker).

## Sibling lessons and rules

- `.claude/rules/file_size_smell.md` — auto-loaded discipline rule
  encoding the §D2 4+4 decision tree.
- `.dev/lessons/2026-05-21-d141-sweep-structural-debts.md` — D-141
  sweep retrospective (the sibling lesson surfacing this drift's
  symptoms before ADR-0099 framed the cause).
- `.dev/lessons/2026-05-21-pure-data-extraction-via-reexport.md` —
  the pattern lesson amended with "When this lesson does NOT
  apply".

## When this lesson dissolves

If a future Phase replaces `scripts/file_size_check.sh` with an
equivalent mechanism (e.g. LSP-driven module-complexity score)
and the replacement preserves the smell-detector framing (= surfaces
gaps for investigation, not absolute thresholds to drive to zero),
this lesson's reusable insight remains valid even though the specific
ADR pointers age out.
