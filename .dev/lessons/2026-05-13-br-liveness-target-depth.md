# Liveness br handler must close only above target depth

**Date**: 2026-05-13
**Keywords**: liveness, br, block_stack, target_depth, regalloc alias,
  control-stack tracking, polymorphic stack, dead-code
**Citing**: §9.9 / 9.9-l-1b-d093-d9 commit

## What happened

`block:break-inner` (Wasm spec corpus) returned 16 instead of 15.
Localised via edge-case probes to a minimal case:
`(block (result i32) (block (br 0)) (i32.const 0x2))` consumed by
`i32.add` with `local.get 0` — yields 4 instead of 2.

## Root cause

`src/ir/analysis/liveness.zig`'s pre-d-9 br handler drained
**all** live vregs (`while (sim_len > 0)`) at the br site,
matching the `return` / `unreachable` semantics. Per Wasm spec
§3.4.4 br N preserves values **below** the target label's
entry stack depth — only intermediate values inside nested
blocks (above target depth) get discarded by polymorphic-
stack rule.

Pre-d-9, `br 0` inside an inner void block closed the
`local.get 0` vreg sitting at sim_stack[0] (below target's
entry depth = 1). Regalloc then aliased that slot with the
subsequent `i32.const 0x2`'s vreg, so the `i32.add` consuming
both V_local0 and V_const2 read the constant's value twice
(2 + 2 = 4).

## Fix

Liveness gains a `block_stack` mirroring lower.zig's
control-stack tracking. On `.block` / `.loop` / `.if`,
push current `sim_len`. On `.end` (non-function), pop. On
`.br N`, compute `target_depth = block_stack[len - 1 - N]`
and close only vregs at indices ≥ target_depth. Function-
level br (N == block_stack_len) and `return` /
`unreachable` retain the full-drain semantics.

## Why this didn't surface earlier

Chunks with br to result-bearing blocks (chunk1, chunk4) had
their top vregs captured into `merge_top_vregs` by the
per-arch emit's `captureOrEmitBlockMergeMov`. The merge slot
provided incidental liveness-extension since its slot was
claimed by a captured vreg with its own range. Only the
**void target** case (br with arity = 0, no merge capture)
exposed the bug, and only when (a) values BELOW target's
entry existed (= the function had operand-stack-flowing
vregs across the br) AND (b) a fresh vreg was pushed AFTER
the br (= the regalloc had something to alias V_below into).

Both conditions present in `chunk2_chained` /
`break-inner`'s pattern #2: outer block consumes
`local.get 0` as one operand of an enclosing `i32.add`, then
its body has `(block (br 0)) (i32.const 0x2)`.

## How to apply this lesson

When implementing or modifying any liveness handler for a
**control-flow op**:

1. Ask: does this op preserve any operand-stack values that
   were on the stack BEFORE the control-frame opened?
2. If yes, do NOT drain sim_stack to zero. Use the control-
   stack to find the relevant entry depth and close only
   above it.
3. `return` / `unreachable` are the only ops where full-
   drain is correct (they exit the function entirely).

The discipline carries forward to `.br_table` (currently
only pops the index; should also use min-target_depth across
all labels) and to any future control-flow proposals (Wasm
3.0 exception handling, tail-calls).

## Reference

- `src/ir/analysis/liveness.zig` (pre-d-9 → d-9 diff at
  the `.br` handler).
- `test/edge_cases/p9/block/break_inner_full.wat` +
  `br_void_below_target_preserves.wat` (regression
  fixtures).
- Related: `2026-05-08-validator-dead-code-in-runtime.md`
  (same shape — single-pass analysis under-shooting
  preservation invariants in dead-code regions).
