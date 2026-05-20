# D-133 sweep blocked: 2-reg `table_emit_scratch_gprs` pool is structurally insufficient

Citing: B119 investigation, 2026-05-20.

## Observation

B118 (commit `c3652994`) declared the named pool
`abi.table_emit_scratch_gprs = [_]Xn{14, 15}` + the overlap
rationale: table/memory emit handlers don't spill mid-op, so
{X14, X15} double-duty as both `spill_stage_gprs` and the
table/memory scratch pool. The B118 prose-level claim was
"the d-64 refactor pattern (load-then-overwrite a single
scratch reg) keeps simultaneous use ≤ 2 registers per op."

B119 attempted the mechanical sweep and found this claim
holds **only** for the trivial single-load ops already
discharged at d-64/d-66 (`emitTableGet` / `emitTableSet` /
`emitTableSize`). The remaining 55 latent sites live in
6 multi-step bulk handlers whose loop bodies hold ≥ 4
simultaneously-live scratches that cannot all map to
{X14, X15} or even the extended {X14, X15, X16, X17}
non-allocatable set:

| Handler | Simultaneously-live scratch | Why ≤ 2 doesn't fit |
|---|---|---|
| `emitTableFill` | W17 dst, X16 val, W14 n, X11 refs, X9 funcptrs, X15 derived_funcptr, X13 derived_typeidx, X10 typeidx_base | Loop body needs refs + funcptrs + typeidx_base + per-iter ref simultaneously (≥ 4 long-lived scratches beyond the 3 op holders) |
| `emitTableCopy` | + X12 src_refs (dual-table form) | Worst case in the codebase; both src + dst refs + funcptrs + typeidx_base live across the loop |
| `emitTableInit` | X11 dst_refs, X12 elem_refs, X9 funcptrs, X13 typeidx_base, X15 per-iter ref + holders | Same shape as emitTableCopy |
| `emitMemoryInit` | X11 seg.ptr (live B→F), X15 seg.len (live B→D1), X12 bounds tmp + per-iter byte | X11 + 3 op holders = 4 long-lived; X12 bounds-tmp pushes to 5 |
| `emitTableGrow` | (none — calls runtime via AAPCS64 args) | No scratch hardcode; not actually a D-133 site |
| `emitElemDrop` | (not a separate function; lives inside `emitTableInit` Step B3) | Subsumed by emitTableInit |

## Why d-64 pattern can't extend

The d-64 "load-then-overwrite a single scratch reg" pattern
works when:
- ONE descriptor read produces ONE long-lived value (e.g.
  `emitTableSize` reads only `len`; X14 holds it through the
  store).
- The bounds-check temporary is short-lived and can reuse
  the descriptor register after the descriptor is consumed.

Bulk ops violate both:
- TableSlice has 3 long-lived fields needed simultaneously in
  the loop (refs ptr, funcptrs ptr, typeidx_base ptr).
- The per-iter ref + bounds-check both need transient scratch
  beyond the long-lived holders.

## Three options going forward (ADR-required)

The B119 task brief explicitly forbade inventing a third
scratch pool autonomously. The three resolution paths:

1. **Per-handler stack save/restore prologue** (Option B in
   `abi_callee_saved_pinning.md`-style). Push X9-X13 onto SP
   at handler entry; pop at exit. Cost: 5 STR + 5 LDR per
   bulk op call site (~40 bytes JIT inline). Pros: trivially
   correct; pool stays {14, 15}; no regalloc coordination.
   Cons: cold-path bloat; SP frame discipline complexity.
2. **Pool extension to {9, 10, 11, 12, 13, 14, 15}** + carve
   these out of `allocatable_caller_saved_scratch_gprs`.
   Cost: regalloc pool shrinks from 5 → 0 caller-saved slots;
   spill pressure rises substantially. Likely unacceptable
   without measurement.
3. **Live-vreg fence**: before bulk op handler emit, walk the
   regalloc state and spill any vreg currently in X9-X13 to
   its home; restore after. Cost: regalloc cooperation, but
   the inline save/restore is only emitted for the affected
   vregs. Most surgical option but requires liveness-walker
   plumbing.

The current latent-bug status (no concrete corpus trigger
since regalloc landed) suggests deferring to a future ADR
rather than blocking §9.12-C close.

## What B119 actually delivered

- Confirmed the 55 sites enumerate per the
  `check_invariant_comments.sh` script.
- Confirmed `emitTableGrow` is NOT a D-133 site (uses AAPCS64
  call regs, not allocatable scratch). Updates D-133 plan.
- This lesson + a debt-body update in D-133 naming the three
  options.

## こうすればもっとデバッグが楽だった

The B118 "≤ 2 simultaneous scratch" claim was prose-only and
not enforced. A comptime check in `op_table.zig` / `op_memory.zig`
that counts unique `inst.enc*(<N>, ...)` register references
per handler body would have caught the gap at B118 design time.

## Cited from

- `.dev/debt.md` D-133 body (updated 2026-05-20)
- `.dev/handover.md` B119 row (mark blocked)
- `.dev/lessons/2026-05-16-regalloc-pool-scratch-overlap.md`
  (original D-132 / D-133 framing)
