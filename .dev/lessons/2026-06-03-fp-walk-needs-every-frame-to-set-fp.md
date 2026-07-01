# An FP-walk unwinder can't traverse a frame that doesn't set FP

**Date**: 2026-06-03 · **Context**: ADR-0134 cross-instance EH on JIT (Cause B)

## Observation

The JIT cross-module bridge thunk (`shared/thunk.zig`) already *established*
an 80-byte frame (`STP X29,X30,[SP,#-80]!` — saving the caller's call-site
LR + FP) but never did `MOV X29, SP`. For normal call-and-return that is
invisible: SP is restored on the way out and nobody reads the FP chain. But
the EH FP-walk unwinder (`unwind.walk`) follows the X29 chain — and because
the thunk left X29 pointing at the *caller's* frame, the callee's prologue
saved the caller's X29 with a saved-LR that points *into the thunk*. So the
walk stepped callee → caller while carrying a **thunk PC**, not the caller's
call-site PC, and the caller's `try_table` (keyed on its call-site PC) was
unfindable. A cross-module throw silently escaped the catch.

## Fix

Add `MOV X29, SP` (= `ADD X29, SP, #0` = `0x910003FD`) right after the STP so
the thunk frame becomes a real chain link. Then the walk is
callee → thunk → caller, and the thunk frame yields the caller's true
call-site return address (the LR the thunk saved at `[X29,#8]`). On arm64 the
20th instruction consumed the prior alignment pad, so `thunk_bytes` stayed 96.

## Rule

Any code that participates in a frame chain an unwinder will walk — prologues,
trampolines, **thunks**, naked stubs — must set the FP register (X29 / RBP),
not just allocate a frame. "Establishes a frame (STP/PUSH)" ≠ "is a walkable
chain link". When adding a new cross-frame emit path, ask: *will the EH /
GC-stackmap FP-walk need to traverse this frame?* If yes, it must `MOV FP,SP`.
The x86_64 thunk still lacks this (D-238) — same gotcha, RBP variant, plus the
D-184 sniffed-RBP interaction.

Related: [[2026-06-03-jit-trampoline-mid-op-clobbers-operands]] (other
cross-frame-emit gotcha); ADR-0134 D1; D-238 (x86_64 parity).
