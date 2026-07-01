# EH catch landing pad: per-clause prelude pattern

**Date**: 2026-05-28
**Citing**: `bc486030` (x86_64 D-182 close), `7987f136` (arm64
D-182 partial), `98acaab9` (handover close).
**Bundle**: 10.E-payload-prop (Cycles 1-5 + D-182).

## Observation

When a try_table catches an exception, the dispatcher's
`landing_pad_pc` JMP target must arrive at code that has already
written the catch's payload values into the catch label's block-
result vreg slots. Multiple catches landing at the same outer
label may have different tag-specific param counts and therefore
need different preludes.

The "single landing_pad_pc per fixup" shape used pre-D-182 worked
for `.catch_all` (no payload) because all matching fixups could
share a single PC value — the post-`emitEndIntra` byte position.
For `.catch_` / `.catch_ref` with N > 0 params, each clause
needs its own prelude code to load the correct payload count
into the block-result vregs.

## Pattern (the design that landed)

At the catch label's `end` op patch site, both arches now:

1. **Probe** matching `landing_pad_fixups` for any `.catch_` /
   `.catch_ref` with `N = ctx.tag_param_counts[tag_idx] > 0`.
2. **No-payload branch**: keep the pre-D-182 simple shape — all
   matching fixups land at `buf.items.len` post-`emitEndIntra`.
3. **Payload branch**: per-clause prelude.
   - For each matching fixup: snapshot `clause_start =
     buf.items.len`, emit prelude (load each
     `eh_payload_buf[i]` into the top-N block-result vreg's
     slot via `gprDefSpilled + gprStoreSpilled`), emit a
     forward-JMP placeholder, set
     `entries[fx.entry_idx].landing_pad_pc = clause_start`.
   - After all matching fixups: `common_pc = buf.items.len`,
     patch each JMP placeholder with `disp = common_pc -
     fx_byte - <instr_size>`.

The block-result vregs sit at `pushed_vregs.items[len - N ..
len]` after `emitEndIntra` — they are the SAME vreg slots that
the fall-through path would have written, so the catch prelude
overwrites them rather than allocating fresh ones. This avoids
a vreg-renumbering pass and keeps the post-block code agnostic
to which path (fall-through vs catch) populated the result.

## Why this matters

- The "single landing_pad_pc per fixup" shape was load-bearing
  for IT-6 (catch_all returns 42 + tagged catch returns 77, both
  N=0 tags). Trying to extend it to N>0 without per-clause
  preludes would have required either:
  (a) folding all payload loads into a single landing pad
      switching on tag_idx at runtime (extra branches per throw
      site), or
  (b) duplicating the post-block code per clause (code bloat).
  The per-clause-prelude + JMP-to-common pattern avoids both.

- The pattern is symmetric across arm64 + x86_64. The only arch
  variance is the encoder set (LDR/STR + B vs MOV r64+MOV
  mem,r64 + JMP rel32). Both use the same regalloc-coordinated
  `gprDefSpilled + gprStoreSpilled` helpers.

## Re-derivability test

If a future contributor were tasked with implementing EH on a
new arch (e.g., RISC-V), the per-clause-prelude shape is the
non-obvious load-bearing detail; without this lesson they'd be
likely to try (a) or (b) above and pay the same investigation
cost. With this lesson, the per-arch port is a straightforward
encoder swap.

## Related

- ADR-0120 D2 (the payload-marshalling shape; complements this
  lesson by specifying the per-Runtime `eh_payload_buf` storage).
- ADR-0114 D2/D6 (try_table emit + zwasm_throw trampoline).
- `src/engine/codegen/arm64/emit.zig` (`landing_pad_fixups`
  patch site at the catch-label `end` op).
- `src/engine/codegen/x86_64/emit.zig` (analogous site).
- `.dev/lessons/2026-05-26-eh-codegen-foundation-atom-rhythm.md`
  (the foundation cycle pattern that this bundle continued from).
