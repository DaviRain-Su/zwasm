# Regalloc op-internal scratch fence — design validation findings

Citing: B121 spike (private/spikes/regalloc-live-fence/, 2026-05-20).

## Observation

ADR-0077's "make regalloc aware of op-internal scratch reservations"
design was validated end-to-end with a self-contained Zig harness
(7 tests, all green). Three findings inform the production
implementation.

## Finding 1 — LIFO free-pool is naturally fence-friendly

The existing LIFO free-pool walker (post-ADR-0037, regalloc.zig
§8b.2-c) integrates the fence with a single change: walk the free
pool from the top down, swap-and-pop the first non-forbidden
entry. This preserves LIFO discipline for non-forbidden slots
while skipping forbidden ones. **No re-architecture of the
free-pool data structure is needed.**

The same loop shape also covers the mint path: a `while
(slotForbidden(mask, n_slots)) n_slots += 1;` step advances
past forbidden ids before the mint takes effect.

Combined, the walker delta is ≈ 30 LOC inside `computeWith`'s
existing `assigned: u16 = blk: { ... }` block, plus a
`forbiddenMaskForVreg` helper (≈ 12 LOC). Well within ADR-0077's
≤ 200 LOC regalloc-plumbing budget.

## Finding 2 — Strict-strict PC shape mirrors ADR-0060 `spans_call`

The fence applies for PCs in `(def_pc, last_use_pc)` — strict on
both ends. A vreg ending **at** the op's PC is consumed by the
op's emit handler **before** any internal clobber happens; the
fence does not apply. A vreg defined at the op's PC is produced
by the op (the produced value lives in a result register, not
the scratch); the fence does not apply.

This is the same PC shape as ADR-0060's `spans_call` (`def_pc <
cp < last_use_pc`). Reusing the shape keeps the regalloc walker's
PC-boundary logic uniform across the call-crossing and
scratch-reservation fences.

## Finding 3 — Per-vreg forbidden-mask precompute is O(N²) but cheap

Building a `forbidden: u16` per vreg by walking its PC range and
OR-ing reservation slots is O(pc_range) per vreg, O(N²) total
worst case. At the validator's `max_operand_stack = 1024` cap
this is ≤ 1M cheap u16 OR operations per `computeWith` call —
well below the level where a sorted-PC-range refinement would
pay back its complexity. **No optimization is needed for Phase
9 / 10 scales.**

A future refinement (if profile demands) would precompute a
per-PC reserved mask once O(N), then accumulate per-vreg by
walking the per-PC array. Same asymptotics, smaller constants.
Out of scope for the initial implementation.

## こうすればもっと早かった

The spike could have been skipped if ADR-0077 had named the LIFO
pool's swap-and-pop integration shape explicitly — but that level
of detail belongs in implementation, not the ADR. The spike was
the right call as a 1-cycle de-risk before committing to the
walker change.

## Cited from

- ADR-0077 (`References` to be amended to point here at next
  spike-touching cycle)
- B122+ impl commits will reference this lesson by path
