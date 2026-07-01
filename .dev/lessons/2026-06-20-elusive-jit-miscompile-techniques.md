# Refuting localizations on an elusive JIT miscompile (D-331A techniques)

**Context**: the D-331A go-runtime JIT miscompile resisted 3+3 investigations,
each "localization" later refuted. These techniques are what actually moved it —
re-derivable, reusable for any interp-vs-JIT divergence hunt.

**1. `mem.cksum` (linear-memory hash diff) is a FALSE oracle once a clock/random
host-call fires.** `clock_time_get` writes nondeterministic wall-clock into guest
memory, so memory legitimately diverges from that call onward — it does NOT mark
the bug. **Use the host-call SEQUENCE as the oracle instead**: diff the ordered
stream of WASI host-call names between `--engine interp` and `--engine jit`; the
FIRST call that differs is the real, deterministic divergence point. (D-331A:
diverges at #5 — interp `args_sizes_get→args_get`, JIT `→clock_time_get`.)

**2. Zero-injection probe REFUTES a "value-class X drives the wrong branch"
hypothesis cheaply.** To test "the bug is the i32 call-return value": gate a probe
that overwrites EVERY captured i32 call return with 0 (then i64, then scoped to
the suspect func). If the divergence is unchanged, that value class is NOT the
driver — no need to trace individual values. Three negatives killed the
call-return theory in one investigation.

**3. "Minimal wat cannot reproduce it" ⇒ the bug is a NARROW trigger, not
general.** If a hand-authored small `.wat` exercising the suspected pattern (e.g.
call→`br_if` under register pressure) runs identically on both engines, the real
bug needs a specific larger context — downgrade any "this is a general codegen
bug" claim to "narrow/niche trigger" and weight ROI accordingly.

**4. The trap of self-reinforcing localization.** Each step found a real
divergence layer (`goargs` branch) but mis-attributed the CAUSE to that layer.
The branch was correct; its INPUT value was wrong from further back. Lesson: a
divergent BRANCH localizes the symptom, not the cause — walk the branch
condition's producer dataflow, don't assume the fault is at the branch.

Use a runtime `dbg.on("channel")` gate for the trace, NEVER a `build_options`
field (see [[2026-06-19-build-options-field-needs-all-exes]]). See [[D-331]].
