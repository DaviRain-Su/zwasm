# 0147 — GC reclamation via an external, walk-safe free-list (§15.1 chunk 2)

- **Status**: Accepted (2026-06-04; autonomous per ADR-0132 / §15.1 planned work)
- **Date**: 2026-06-04
- **Author**: claude (autonomous, /continue bundle 15.1-gc-reclamation)
- **Tags**: Phase 15, GC, mark-sweep, reclamation, free-list, non-moving, D-211
- **Amends**: ADR-0115 §10 closing note ("dead bytes leak until process exit");
  ADR-0135 (no-reclaim interim — this is the reclamation it was interim for)

## Context

Through §15.1 chunk 1c the mark-sweep collector ran in production but `runCollection`
(`collector_mark_sweep.zig`) only **counted** `dead_bytes` — it never freed. So a
natural interp alloc-loop (`local = struct.new(...)` each iteration, prior objects
die) grew `heap.cursor` without bound: each collection's live object sits near the
TOP of the slab, with the dead objects as HOLES below it, so a mere cursor-rewind
reclaims nothing. Hole reclamation (a free-list) is required.

The §15.1 survey (`private/notes/p15-gc-survey.md`) sketched an **intrusive**
free-list: store the next-free link inside each dead object's own bytes. That is
unsafe here.

## Decision

**External, size-keyed free-list on the Heap, rebuilt every sweep; reuse-before-bump
in `Heap.allocate`.**

- `Heap` holds `free_list: ArrayListUnmanaged(FreeSlot)` where `FreeSlot =
  {offset: u32, size: u32}`. Each `runCollection` first `clearRetainingCapacity()`s
  it, then walks the slab and appends every **dead** (unmarked) object's
  `(offset, size)`. "Dead" is recomputed each sweep (no persistent free-bit), so a
  conservatively-retained slot (marked by the chunk-1b stack scan, which runs in the
  same collection's mark phase BEFORE sweep) is simply never added.
- `Heap.allocate(size)` scans `free_list` for an **exact-size** match first; on a hit
  it pops that slot and returns its offset WITHOUT advancing `cursor`; on a miss it
  bumps as before. The caller stamps a fresh header over the reused slot.

## Rejected alternatives

- **Intrusive free-list** (link in the dead object's bytes) — both `runCollection`
  and `scanNativeStackRoots` (chunk 1b) walk `[min_align, cursor)` decoding each
  `ObjectHeader` to advance by object size. Overwriting a dead object's header (or
  the `info` typeidx the struct-size decode needs) with a link **derails the walk**.
  Preserving the header AND finding link space fails for zero-payload structs
  (size == header_size, no payload to hold a link). The external list sidesteps all
  of this: dead slots keep their original headers (walk stays valid) until reuse
  overwrites them.
- **Cursor-rewind only** (drop `cursor` to the highest live object's end) — needs no
  free-list but reclaims only a dead TAIL, not holes; the natural alloc-loop keeps a
  live object near the top, so it bounds nothing.
- **Persistent free-bit in the header** — avoids recomputing dead-ness but adds a
  second reserved `info` bit (mask churn in every size decode) for no benefit, since
  the sweep already visits every object and can rebuild the list in O(objects).

## Consequences

- **Walk safety preserved**: every slot in `[min_align, cursor)` always decodes to a
  valid `ObjectHeader`, so the conservative scan + sweep keep working after
  reclamation lands.
- **Exact-size, first-cut**: a linear `free_list` scan for an exact size match. Size
  bucketing / best-fit / coalescing is a later optimisation (§15.2+), not load-bearing
  here. Holes of a size never re-requested are not reclaimed until then — bounded
  waste, never incorrect.
- **OOM during sweep**: appending to `free_list` can fail (it allocates via
  `heap.parent`), but `collectFn` returns void. On OOM the dead slot is simply not
  enqueued this cycle (cursor grows instead) and a `reclaim_oom_count` is bumped —
  best-effort reclaim, **never** a freed-live-object. `clearRetainingCapacity` keeps
  the backing capacity, so steady state does not allocate.
- **UAF gating**: reuse is the first operation that actually frees memory, so missed-
  root → UAF becomes possible HERE. It is gated behind chunk 1b (object-start-
  validated native-stack scan) + chunk 1c (the collection trigger that enables that
  scan). For pure interp the operand-stack/locals/globals walk is already complete;
  the stack scan covers JIT-spilled refs (ADR-0128 §2 spill-at-call model). The JIT
  alloc trampoline still bypasses the trigger (D-258) — once it is wired, the same
  free-list serves it.
