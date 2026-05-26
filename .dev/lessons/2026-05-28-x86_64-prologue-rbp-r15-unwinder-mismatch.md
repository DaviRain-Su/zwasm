# x86_64 prologue's R15 push lands RBP at saved-R15, not saved-RBP

**Date**: 2026-05-28
**Citing**: `90cba314` (D-184 close), `200c9600` (D-184 probe;
reverted), `c05b0393` (D-183 single-frame foundation).

## Observation

The zwasm x86_64 JIT prologue emits, in order:

```
PUSH RBP        ; saves caller's RBP at [RSP, +0] (after push)
PUSH R15        ; (if uses_runtime_ptr) saves R15 below saved RBP
MOV RBP, RSP    ; captures RBP AFTER both pushes
```

The MOV captures RBP at the saved-R15 slot, so the frame prefix
is NOT the standard SysV layout:

| Slot | uses_runtime_ptr=false | uses_runtime_ptr=true |
|---|---|---|
| `[RBP+0]` | saved RBP | **saved R15** (= rt ptr value) |
| `[RBP+8]` | saved RIP | saved RBP |
| `[RBP+16]` | first stack arg | saved RIP |

This is intentional for zwasm's local addressing (the comments
at `src/engine/codegen/x86_64/emit.zig:260-267` document
"[RBP - 8] R15 occupies" which matches *post-PUSH-R15* layout)
but breaks any unwinder that assumes the standard SysV
`[RBP+0]=saved RBP / [RBP+8]=saved RIP` shape.

The arm64 sibling is immune: the AAPCS64 prologue is `STP X29,
X30, [SP, #-16]!; MOV X29, SP` — saved X29 and X30 sit at fixed
slots from MOV. zwasm's X19 / X24..X28 are NOT pushed in the
standard prologue; they're handled via bridge thunks (per
`abi_callee_saved_pinning.md`).

## The fix

`src/engine/codegen/x86_64/frame_chain.zig::loadFrameSniffed`
takes a `*const CodeMap` and disambiguates via `cmap.lookup`:

1. If `cmap.lookup(slots[1])` is `.inside` (= JIT body address),
   the function used standard SysV — return
   `(caller_fp = slots[0], caller_rip = slots[1])`.
2. Else if `cmap.lookup(slots[2])` is `.inside`, the function
   used zwasm's uses_runtime_ptr layout — return
   `(caller_fp = slots[1], caller_rip = slots[2])`.
3. Else neither slot is a JIT address → frame chain has escaped
   the JIT block (entry shim / host stack). Fall back to the
   slot 0/1 default; the unwinder's caller sees an out-of-range
   PC and either terminates or steps further.

The sniff is unambiguous because saved-RBP / saved-R15 are
stack / heap addresses (never in the JIT block), but the saved
RIP at the correct slot necessarily resolves to `.inside`.

`frame_chain_adapter.loadFrameLink` dispatches per-arch:
- aarch64 → existing `loadFrame(fp)` (no sniff needed).
- x86_64 → `loadFrameSniffed(fp, code_map)`, with the CodeMap
  pulled from `adapter_ctx.normalize_ctx` (which the production
  path's `code_map.adapterContextFor` sets to the CodeMap
  pointer). Unit tests that supply non-CodeMap ctx fall back to
  plain `loadFrame`.

## Why this matters

Without the fix, x86_64 cross-frame EH (callee throws, caller's
try_table catches) would always SEGV: the unwinder reads
`[callee_RBP, 0]` expecting test's RBP, gets the runtime
pointer value (= rt ptr address), tries to deref as a frame
pointer → segfault at the rt's `vm_base` empty-memory sentinel
(`0x1000`).

Single-frame EH happens to work without the sniff because the
walker matches on the FIRST iteration (in the throw frame); no
caller-frame load is needed.

## Re-derivability anchor

Investigation procedure (mirrors `extended_challenge.md` Step 5
permanent-diagnostic discipline):

1. Cross-frame e2e fails with SEGV at `loadFrame.slots[0]` deref.
2. Add diagnostic probe in `trampolineCore` + `unwind.walk`
   emitting all numerical values per iteration (committed as
   `200c9600`; reverted in fix commit).
3. Capture probe output via ubuntu run; observe `caller_lr`
   from the FIRST walk step is a stack address (NOT a JIT
   body address). Saved-RBP and saved-RIP slots are
   inverted-from-expected.
4. Read prologue.zig / emit.zig at the PUSH-RBP / PUSH-R15 /
   MOV-RBP-RSP byte emit sites; confirm order.
5. Implement sniffed loadFrame; revert probe; verify.

The full chain `probe → identify slot inversion → sniff fix`
took one cycle once the probe data was in hand. The sniff
mechanism (rather than reordering the prologue) avoids
disturbing the rest of the codebase's RBP-relative addressing
conventions (`r15_save_off`, `base_off_for_locals`,
`spill_base_off`).

## Alternative considered: reorder the prologue

`PUSH RBP; MOV RBP, RSP; PUSH R15` would give the standard
SysV layout. Rejected because:
- All RBP-relative addressing in emit.zig (lines 196, 428,
  467, 533, `spill_base_off` computation) is computed against
  the current "RBP at saved-R15" layout. Reordering would
  require updating each call site and re-deriving every
  offset constant.
- `assertProloguePrefix` (`prologue.zig:118+`) hardcodes the
  byte sequence. Reordering would break its checks.
- Existing JIT body-byte tests (`emit_test_*.zig`) include
  hardcoded prologue prefix offsets via `prologue.body_start_offset`
  which currently assumes the post-D-184 byte order.

The sniff is contained, doesn't disturb existing layout
invariants, and runs only when uses_runtime_ptr functions
participate in the unwind chain (per CodeMap lookup).

## Related

- ADR-0114 D5/D6 (EH design + zwasm_throw trampoline).
- D-183 (single-frame mod-relative PC + DWARF ret_addr-1).
- D-184 (this discharge).
- `2026-05-28-eh-test-wrapper-host-fp-walk-segv.md` (sibling
  lesson: test wrappers must install sentinel frames; this
  lesson covers the production walker analog).
- `src/engine/codegen/x86_64/emit.zig:260-267` (prologue
  byte order + local layout comments — source of truth for the
  zwasm-specific frame shape).
- `src/engine/codegen/x86_64/frame_chain.zig::loadFrameSniffed`
  (the load-bearing fix).
