# The `UnsupportedEntrySignature` for go_* came from an upstream fixed cap, not the entry gate

**Context**: D-331(A). The handover's lead (carried 1 cycle) hypothesised that
`zwasm run --engine jit go_hello` rejecting with `UnsupportedEntrySignature` was a
*downstream entry-signature ASYMMETRY* — Go's `_start` is void `()->()` idx 1326, and
`runWasiLenient` (runner.zig:466) "HANDLES void at L502 yet still rejects", so the
suspect was `compiled.func_sigs[idx]` module-vs-defined index. Plausible, specific, wrong.

**What actually happened**: a one-line debug print at the *hypothesised* reject site
(runner.zig, after the entry gate) **never fired**. That single negative localised the
fault UPSTREAM of the entire entry logic. Moving the print earlier (and then into
`setupRuntimeLinked`) found it: `if (table_size > 4096) return UnsupportedEntrySignature`
— Go's funcref table is **5790** entries. The interp (`instantiate.zig` allocs `entry.min`
cells uncapped) ran go_* fine; the JIT had an arbitrary early-dev cap. Same error *name*,
completely different *site* and *cause*. Fix: remove the cap (allocator-backed buffers,
no fixed-array dependency) → go_hello compiles + instantiates + runs.

This is the **THIRD** instance of the same dynamic-vs-fixed-cap barrier hit by fat
standard-Go: `[256]Frame` control stack (→ doubling `block_stack`, `10d7d2b2`), now
`table_size > 4096`, and still-open `max_slots=4095` (go_regex, D-289). A magic
`> NNNN ... return Error` in a setup/codegen path is a recurring smell.

**Rules**:
1. A shared error name (`UnsupportedEntrySignature` is returned from ~40 sites) does
   NOT locate the fault. Before trusting a hypothesis that names a specific site,
   confirm the code even REACHES it — a debug print that doesn't fire is decisive and
   cheaper than reading the suspected function. Bisect the call chain, don't assume.
2. When interp runs X and JIT rejects X with a setup-class error, suspect a
   JIT-only fixed cap that the interp lacks (engine asymmetry), not an ABI/sig subtlety.
3. Removing a barrier often reveals the NEXT one — here go_* then JIT-miscompile (Go
   runtime corruption, non-deterministic `poll_oneoff`/`badmorestackg0`/`unlock of
   unlocked lock`). Correct output printed first ⇒ a late memory-corruption miscompile
   (D-330/D-283 class), not the thing you just fixed. Re-frame the debt; don't claim
   the cluster closed.

Same family as the harness-artifact lessons: the mechanism (entry dispatch) was correct;
a guard elsewhere was the gap. Cite: D-331, D-332, D-289, D-330.
