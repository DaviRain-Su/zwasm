# Session retrospective — 4 structural risks most likely to be orphaned (+ 1 process note)

**Date**: 2026-06-04
**Citing**: user-requested retrospective at the §15.5 close (GC reclamation §15.1, the
§15.2/15.3/15.4 perf folds, D-245 win64 trampoline, D-260 x86_64 SIMD bugs all landed
this session). This is the durable anchor for those risks; each actionable one has a
swept debt row so it is re-encountered every `/continue` Step 0.5.

## The risks (highest-stakes first)

1. **GC-on-JIT rooting correctness is unverified → latent UAF — [[D-261]].** Reclamation
   now frees; the conservative scan's JIT-path correctness rests on the ADR-0128 §2
   spill-at-call assumption with NO adversarial test (a register-only-held GcRef at a
   collection point = silent UAF). Compounded by D-258 (JIT path doesn't even trigger
   collection yet). Highest stakes, latest-surfacing failure mode.

2. **x86_64/win64 emit correctness is under-verified by the gate topology — [[D-262]].**
   The 2-host per-chunk gate (Mac + ubuntu-often-narrow-`test`) + windowsmini-only-at-
   phase-boundary let D-260's x86_64 SIMD bugs ship "RESOLVED"; cross-COMPILE was mistaken
   for cross-RUN ([[2026-06-04-cross-compile-is-not-cross-run]]). Any newly-added per-arch
   emit may carry latent bugs. Needs a process fix (emit chunks → x86_64 test-all) + an audit.

3. **"v2 ≈ v1 parity" is an inference, never measured vs v1 — [[D-263]].** Three perf folds
   (ADR-0149/0150/0151) rest on per-op-vs-wasmtime + spill-efficiency, not a v2-vs-v1 bench.
   §15.P's parity-vs-v1 + W45 loop-isolated measurement are the load-bearing un-done work,
   easy to hand-wave at close. Make them HARD §15.P gates.

4. **The cohort-preservation root fix is perpetually deferred — [[D-210]].** The "MOV-install
   cohort without prologue stack-save" convention (ADR-0017) has generated callee-saved bugs
   at four seams (D-142/D-206/D-210/D-245), each patched at the seam. Decide consciously:
   schedule the root fix (D-210) OR adopt "perpetual per-seam patching" as documented policy.

## Process note (no debt row — behavioural)

The autonomous loop is **least efficient + most prone to deferral exactly where stakes are
highest**: remote-dependent (win64/windowsmini), correctness-critical (GC rooting, ABI asm),
and measurement-gated (perf). This session: §15.5 took 3 design turns before code; GC rooting
was accepted on "tests pass"; the x86_64 emit bug hid until a phase-boundary run. "measure-
first" and caution are correct, but can slide into "defer the hard thing." **Conscious
counter-weight: deliberately thicken time + verification on remote/correctness-critical work
rather than letting it ride the longest.**

## What is NOT concerning (balance)

Core parse/validate/interp/the bulk of codegen, and the GC/EH/tail-call features, are solid +
well-tested. The perf-fold decisions were evidence-based + honest. The scaffolding (ADRs/rules/
lessons/debt/gates) supports the loop well. Risk is concentrated in the 4 items above; #1 and
#2 are the two whose failures surface latest and hurt most.
