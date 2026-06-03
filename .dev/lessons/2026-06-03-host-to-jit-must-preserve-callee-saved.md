# Host→JIT calls must preserve callee-saved regs; an inlined crash trace mis-blames the deinit

**Date**: 2026-06-03 · **Context**: D-245 (`zwasm run --engine=jit` SEGV in ReleaseSafe)

## Observation

`zwasm run --engine=jit <module>` worked in Debug but SEGV-aborted (exit 134, "Segmentation
fault at 0x18") in ReleaseSafe — on EVERY module, including an empty `(func (export "_start"))`.
The crash trace pointed at `owned.deinit` → `rawFree`, so the first diagnosis was "a bad free in
RuntimeOwned.deinit". WRONG, twice over:

1. The trace LINE was misattributed by ReleaseSafe inlining. Skipping `owned.deinit` moved the
   crash to `compiled.deinit:204` (`deinitFuncResult`). Both deinits are VICTIMS.
2. Skipping `callVoidNoArgs` (the JIT call itself) → NO crash, deinits run clean. So the **JIT
   execution corrupts the host**, and the next `free` after it trips on the garbage.

Root cause: the arm64 JIT prologue MOV-installs the pinned runtime cohort (X19/X24/X28/… —
arm64 **callee-saved**) from `rt` WITHOUT stack-saving the caller's values (ADR-0017 / D-210), so
the JIT body clobbers X19–X28 and can't restore them. But `entry.invokeAndCheckVoid` calls the JIT
via a plain `@call(.auto, f, .{rt})` (f = `callconv(.c)`). In a C call the CALLER keeps live values
in callee-saved regs across the call, trusting the callee to preserve them. ReleaseSafe's optimizer
does keep host values live in X19–X28 → the JIT clobbers them → the host computes a garbage slice
ptr (~0x18) → SIGSEGV at the first post-call `free`. Debug keeps nothing live there → no corruption
(luck, not correctness). This is LATENT PROJECT-WIDE: every host→JIT call is ReleaseSafe-unsafe;
it never bit because all JIT execution (spec runner, runI32Export) runs in Debug. `--engine=jit`
was the first release host→JIT path.

## Rule

- **A "works in Debug, SEGVs in ReleaseSafe" crash freeing a garbage pointer is almost never a
  bad-free bug — suspect callee-saved-register corruption by called foreign/JIT code.** The freed
  slice is garbage because a host pointer in a callee-saved reg was clobbered across a call.
- **Bisect a post-call corruption by SKIPPING phases, not reading traces.** Inlining lies about the
  line. Skip the cleanup → crash moves (cleanup is a victim). Skip the call → crash vanishes (the
  call is the corruptor). Three `// comment out + rebuild` cycles localised it; the trace alone sent
  the first diagnosis to the wrong file.
- **Any host→JIT entry boundary MUST save/restore the host's callee-saved set** (arm64 X19–X28 +
  FP/LR; x86_64 RBX/RBP/R12–R15) around the `blr`/`call`, because the JIT uses those regs as runtime
  invariants and does not honour the C callee-saved contract. A plain Zig `@call` to a `callconv(.c)`
  JIT pointer is NOT enough.
- **Debug-only tests hide release-only ABI bugs.** A JIT-execution regression test must run in
  ReleaseSafe (the runWasmJit test was Debug-only → the crash shipped).

Related: D-245 (this); D-210 / ADR-0017 (cohort MOV-install, not stack-save); `test_discipline.md` §3
(host-FP-walk sentinel — same family of host↔JIT ABI hazards).
