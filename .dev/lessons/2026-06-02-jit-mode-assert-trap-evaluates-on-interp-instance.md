# A JIT-mode test "fail" can be a harness eval-gap, not a codegen bug

2026-06-02 (D-233). The wasm-3.0 spec runner under `ZWASM_SPEC_ENGINE=jit`
reported 8 `assert_trap` failures (ref_cast_null ×4, array_init ×2, data_drop ×2).
I spent ~5 cycles debugging the JIT GC `ref.cast_null` codegen — disasm hypotheses,
runtime probes, "operand-0 at fixed positions," TDD repros — all chasing a bug that
does not exist in the codegen.

Root cause (confirmed by reading the runner, not the codegen): in jit_mode the
runner evaluates `assert_return` on the JIT (`cur_jit` / `runScalar`,
`spec_assert_runner_wasm_3_0.zig:344`) but evaluates `assert_trap` on the INTERP
instance (`invokeInstanceTrap(instances_list.items[idx], …)`, :1068). AND the setup
`(invoke "init")` action in jit_mode runs ONLY on `cur_jit` (:1242
`const inst = if (cur_jit) |j| j else continue`), never on the interp instance. So
the interp instance's table/globals are never populated by the JIT-applied setup;
`ref_cast_null`'s `table.get` returns null; `ref.cast_null` on null passes (nullable)
→ no trap → "fail". The A/B was already in the data: interp-mode (setup→interp,
trap→interp, synced) = 562/0; jit-mode (setup→cur_jit, trap→interp, STALE) = 554/8.
The only delta is which instance got the setup invoke. The JIT trampolines
(`jitGcRefCast`, `jitGcArrayInitData`) share the interp's passing subtype/OOB checks
and the single-cast unit tests pass — the code was never the problem.

**Rules:**

1. Before debugging codegen for a backend-specific test failure, VERIFY which
   engine/instance the assertion actually executes on. A "JIT mode" run may route
   only a SUBSET of assertion kinds through the JIT (here: assert_return yes,
   assert_trap no) and silently fall back to the other engine for the rest.
2. State-dependent assertions need their SETUP applied to the SAME instance that
   evaluates them. If setup goes to instance A and the assertion reads instance B,
   B is stale → spurious pass/fail unrelated to the code under test. Check the
   setup-action handler's instance target first.
3. An A/B already in hand (interp 562/0 vs jit 554/8, same totals, 8 flip) localizes
   to the ONE path that differs between the two runs — here the setup-invoke
   instance. Diff the two configs before reaching for a disassembler.
4. Confirm-vs-codegen tell: the trampoline/algorithm is SHARED between backends and
   one backend passes → the bug is almost never the shared algorithm; look at the
   per-backend plumbing (invocation, arg passing, instance/state wiring).

Proper fix (separate, substantial): route jit_mode `assert_trap` through `cur_jit`
(param-bearing JIT invoke + trap_flag detection) so "both backends" (ADR-0128 §10)
actually verifies JIT traps — today it does not. Same family as
`2026-06-02-detection-without-enforcement-dead-gate` / `gti-tied-to-heap-need`:
the mechanism existed; the wiring (which engine/instance) was the gap.
