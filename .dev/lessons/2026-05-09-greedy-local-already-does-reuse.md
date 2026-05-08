---
name: greedy-local-already-does-reuse
description: regalloc.compute's busy-mask check `earlier.last_use_pc > r.def_pc` is an inline slot-reuse mechanism; "greedy-local" in v2 is not "no reuse"
type: feedback
---

# greedy-local-already-does-reuse

`src/engine/codegen/shared/regalloc.zig:compute` (the so-called
"greedy-local" allocator from §9.7 / 7.1) is not "one-fresh-
slot-per-vreg with no reuse" as the §9.8b / 8b.2-a survey
described. The busy-mask scan at line 188-203:

```zig
for (live.ranges, 0..) |r, vreg| {
    @memset(&busy, false);
    for (live.ranges[0..vreg], 0..) |earlier, ev| {
        if (earlier.last_use_pc > r.def_pc) busy[slots[ev]] = true;
    }
    var s: u16 = 0;
    const assigned: u16 = while (s < max_slots) : (s += 1) {
        if (!busy[s]) break s;
    } else { ... };
    slots[vreg] = assigned;
    if (assigned + 1 > n_slots) n_slots = assigned + 1;
}
```

implements slot reuse via the inverted lifecycle check:
`earlier.last_use_pc > r.def_pc` flags only **still-live**
earlier vregs as busy. Dead vregs (those whose last use was at
or before this vreg's def) leave their slot unmarked, so the
"smallest free slot" picker reuses it.

**Why:** The W54-class lesson informed v2's §9.7 / 7.1
allocator design from day 1: liveness is a const input
(P13), and the allocator's correctness depends on the
overlap relation, not on a separate slot-aging clock. The
busy-mask is a clean encoding of overlap.

**How to apply:** When surveying or describing v2's
allocator behaviour, **read the actual code** before
accepting upstream framing ("greedy-local means per-vreg
slot, no reuse" is true for naïve descriptions of
"greedy-local" from cranelift/regalloc2 README, but
**not** for v2's busy-mask implementation). The 2-vreg
test at line 273 + the just-added 3-vreg test prove
reuse works. The ADR-0037 Option 1 framing
("free-pool implements slot reuse on dead vregs as the
8b.2-c MVP") is correct in mechanism but redundant in
result — both shapes produce the same `n_slots` on
straight-line code.

The actual bench-delta wins for §9.8b / 8b.2 come from:

1. **Class-aware allocation** (D-036 §option-b, mentioned
   in `regalloc.zig:131-133` as "Tighter accounting lands
   when the allocator becomes class-aware"): tighter spill-
   frame accounting when GPR + FP vregs share slot ids
   beyond their respective register pools. Real win ~3-5%
   on FP-heavy fixtures.
2. **Live-range splitting at loop boundaries** (Option 2,
   deferred to Phase 15 per ADR-0037): split-then-merge
   produces measurable gains on loop-heavy fixtures, but
   requires the Phase 15 coalescer detection lift to
   handle the split-induced moves cleanly.

The free-pool refactor still has value as compile-time
speedup (no per-vreg `@memset(&busy, false)` over 4 KiB)
and as Phase 15 substrate (free-pool pops produce explicit
same-slot reuse events the coalescer subscribes to). But
it's **not a bench-delta lever** at the runtime level.

## Pattern (the rule itself)

When upstream (cranelift / regalloc2 / the surveys
referencing them) describes "greedy-local" or "no reuse"
allocators, do not assume v2 matches that description.
v2's busy-mask is an inline slot-reuse mechanism. Read the
implementation; cite the line that does the check; let the
test cases (existing + new) prove the behaviour.

## Citing

- `8381dfb` ADR-0037 design framing (introduced the
  framing this lesson corrects)
- discovery commit `<backfill>` (this resume's 8b.2-c
  implementation)
- ADR-0037 Revision row 2026-05-09 (load-bearing
  amendment)
- ADR-0027 (callee-saved pool reduction; the original
  context for the busy-mask design)
