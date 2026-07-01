# A global-registry predicate cannot REPLACE an always-available local CodeMap — union them

**Date**: 2026-06-14 · **Context**: D-238 / ADR-0185 (c), x86_64 cross-instance EH frame-walk.

## Observation

The x86_64 frame-chain sniff disambiguates two prologue layouts by testing whether a
candidate saved-RIP slot is a valid *code* address. The single-instance design fed it the
THROWING instance's CodeMap directly (`frame_chain_adapter.Context.normalize_ctx`). The
cross-instance redesign (D-238) needed membership across MANY instances + bridge thunks, so
it switched the sniff to `eh_registry.isCodeAddr` (a process-global registry).

That **replaced** the local CodeMap instead of **extending** it — and broke single-instance
EH. The trap: not every instance that throws is *registered* in `eh_registry`. Only the
cross-instance spec runner registers; the edge-runner (and any single-instance embed) does
not. So `isCodeAddr` returned `false` for every address → the sniff mis-resolved the layout
→ walked into a garbage `caller_fp` (~0x1000) → SEGV reading `slots[1]` (0x1008). Mac never
sees it (arm64 uses pure-pointer `loadFrame`, no sniff); only the x86_64 ubuntu gate caught
it (`808090f2`).

## Rule

When a global lookup REPLACES a context-local one, ask: *is the local source always
present, and is the global guaranteed to be a superset?* Here the local CodeMap is ALWAYS
present (passed per-throw via `normalize_ctx`) but the global registry is NOT a superset
(unregistered throwers are absent). Fix = **union**: `local.lookup == .inside OR
global_predicate(addr)`. Single-instance resolves via the always-present local; cross-
instance via the global. Cheap, and correct in both regimes.

## Tells

- A membership/resolution predicate that depends on an OPT-IN registration step, used on a
  path that does not perform that step.
- "It works in the integration harness (which registers everything) but crashes in the
  minimal/embedded path."
- A frame-walk that reads `slots[N]` off a small/garbage `fp` — the upstream layout
  resolution diverged, not the read itself.

Related: [[2026-06-14-jit-eh-landing-pad-emit-gotchas]] (sibling JIT-EH codegen traps).
