---
name: hoist-branch-targets-as-pc
description: ZIR hoist's branch_targets[] update treated entries as PCs and shifted them through pc_shift[]; entries are actually Wasm br/br_table block-stack depths. Bug masked at cap=4 (small Δ → coincidentally valid depths) but inflated past labels.items.len at cap > ~10-20, triggering br_table UnsupportedOp on 10/55 realworld fixtures (D-053 root cause).
type: feedback
---

# §9.8a / 8a.5 lesson — `branch_targets[]` are depths, not PCs

## What happened

`hoist/pass.zig`'s instr-list rewrite shifts PCs across the
synthetic prologue insertion. The same loop that updated
`func.blocks[].start_inst` / `.end_inst` (correct: PC fields)
ALSO did:

```zig
for (func.branch_targets.items) |*tgt| {
    tgt.* += pc_shift[tgt.*];
}
```

But `branch_targets[]` entries are **Wasm br/br_table
block-stack depths** (per `lower.zig:emitBrTable`'s
`readUleb128(u32, ...)` of label indices + `arm64/op_control.
zig:emitBranchToDepth`'s `depth > labels.items.len →
UnsupportedOp`). They are NOT PCs.

At `max_hoists_per_func = 4`, depth values (typically 0/1/2)
plus small shifts often landed by coincidence on valid
block-stack indices. At cap > ~10-20, depth-shift inflation
exceeded `labels.items.len` → `br_table` returned
`UnsupportedOp` on 10/55 realworld fixtures
(rust_file_io, go_string_builder, go_crypto_sha256, …).

The existing test "shifts branch_targets across hoist
prologue" locked in the wrong semantics: it asserted that
`branch_targets[0] == 2` after hoisting a 1-iteration loop
— treating the value as a PC pointing at the loop header.
That depth-vs-PC confusion was the cementing artefact.

## Fix (2e0022c)

Removed the `branch_targets[]` shift entirely. Renamed/
rewrote the test as "leaves branch_targets[] depths
invariant across hoist prologue" — depth values are
unchanged by hoist's PC shift.

`max_hoists_per_func` cap (was 4) fully removed. Mac local
realworld_run_jit baseline preserved at 52/55 compile-pass +
15/55 RUN-PASS RUN-JIT-VERIFIED with no cap.

## Lesson

This is a **single-axis-mistake hidden by a small-input
mask** failure mode. ROADMAP §14's `single_slot_dual_meaning`
rule covers a related case (one slot serving two semantic
axes); this is the dual: **one type used for two semantic
axes (PC vs depth), with the test fixture's small-input
shape coincidentally satisfying both interpretations.**

Diagnostic patterns that would have caught it earlier:

1. **Type-named-after-meaning over type-named-after-shape**:
   `branch_targets: ArrayList(u32)` is opaque; `branch_targets:
   ArrayList(BranchDepth)` (where `BranchDepth = enum(u32) {
   _ }` or distinct typed wrapper) would have made the
   PC-shift line a type error on a fresh hoist author's
   editor.
2. **Single-input tests as anti-pattern when an axis spans
   multiple values**: the existing test used `branch_targets
   = [0]` only; a test with a depth value that *would*
   distinguish "shifted as PC" from "left as depth" (e.g.
   depth=2 with hoists in the middle of the function) would
   have failed at write time.
3. **Refactor-time grep**: searching `branch_targets` and
   reading op_control.zig + lower.zig within 30 seconds
   would have surfaced the `depth > labels.len` semantic
   discriminator. (The bug-fix-time survey rule
   `bug_fix_survey.md` Step 2 codifies this.)

## When to escalate to ADR

Promote to ADR if any of:
- A future analysis pass introduces a similar pattern (a
  per-instr metadata field shifted alongside PCs).
- 3+ commits cite this lesson.
- The "type-named-after-meaning" guidance becomes a
  load-bearing rule applicable beyond hoist.

For now, this lives as observational; the hoist fix is
mechanical and the cap is gone.

## Citing

- §9.8a / 8a.5-c/d fix commit: `2e0022c` (post-rebase
  `34a3ac1`)
- §9.8a / 8a.5-b diagnostic errdefer: `b204ad3`
- §9.8a / 8a.5-a reproducer findings: `f212892`
- ADR-0031 (ZIR-stage hoist pass) — Revision history needs
  amend referencing this lesson (`<backfill>`)
