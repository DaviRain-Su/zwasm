## EH-codegen foundation-atom rhythm — when does atomic SHIP stop being progress?

**Date**: 2026-05-26
**Keywords**: autonomous loop, architectural chunk, atomization, foundation atom, EH codegen, integration debt, observable behavior, architectural_spike rule
**Citing**: §10.E / 10.E-codegen-1..4b + 10.E-N-4 (13 cycles 2026-05-26)

## What happened

The autonomous `/continue` loop landed 13 consecutive cycles of EH
codegen foundation atoms across `engine/codegen/shared/` (exception_table,
unwind, frame_chain_adapter, code_map, zwasm_throw) + per-arch
(arm64+x86_64 frame_chain, sp_restore, op_exception_handling skeletons)
+ EmitCtx.exception_table_builder field. Each cycle shipped a
test-gated commit (Mac test-all GREEN, lint exit 0, ubuntu OK on
next resume). Each cycle's diff had a clear observable behavior
point — usually unit tests on the new primitive, occasionally
axisOf comptime tests on per-op axes declarations.

But the EH-on-JIT path didn't move during these 13 cycles. No
spec test flipped from FAIL to PASS. The architectural foundation
grew + tests pass — but the integration into emit.zig's compile
flow (which would actually exercise EH end-to-end) needs a
multi-cycle architectural design pass, not further atomization.

## Root cause

Two design pressures pulled the loop into per-cycle atomization:

1. **The per-cycle commit rhythm rewards small atoms** —
   each cycle's "1-file landed + tests green + commit pair pushed +
   ubuntu kicked" is a clean status story. The cycle-end one-sentence
   summary feels like progress. Many small atoms × N cycles still
   feels productive even when the integration story remains
   unstarted.

2. **The next integration atom is genuinely architectural** — try_table
   emit body needs `ctx.exception_table_builder` access, ZIR catch_vec
   accessors, pc_start/pc_end fixup mechanism, and integration into
   emit.zig's compile flow which is ~1500 lines. throw / throw_ref
   emit needs runtime ABI marshalling (tag_idx → argreg, payload
   pop count → argreg, CALL zwasm_throw fixup) + the dispatch
   needs the per-Instance code_map populated by the runner. Both
   are multi-cycle in any honest accounting.

Per `.claude/rules/architectural_spike.md`: "code commit on
zwasm-from-scratch MUST have an observable behaviour point that
exercises the diff." The foundation atoms each satisfied this
literally (unit tests on the new helper) but the WIDER
integration's observable behavior (= EH spec test pass) never
moved. This is the "preparatory infra without observable
behaviour" anti-pattern at the cycle-chain scale, not the
single-cycle scale.

## Path forward

For the EH-on-JIT integration the right next move is **either**:

- (a) **Spike-first design pass**: outline the integration in
  `private/spikes/eh-jit-integration/` (gitignored per
  spike_lifecycle.md). Capture the compile() control-flow changes,
  the EmitCtx population at compile entry, the post-emit
  ExceptionTable finalisation into CompiledWasm, the runtime
  dispatch from compileWasm consumers. Spike outcome → ADR
  amendment OR direct integration impl with clear scope.

- (b) **Phase-boundary review**: 10.E impl is genuinely
  multi-cycle. The Phase 10 design plan / ROADMAP §10 row tracks
  it as a single 10.E task. Mark it as "needs focused
  multi-cycle design pass; not autonomous-loop-eligible at the
  per-cycle granularity" and pivot the autonomous loop to other
  Phase 10 work (10.TC tail-call has the same shape; 10.G GC is
  blocked-by heap; 10.M-realworld is toolchain-blocked).
  Resume EH integration when there's session budget for
  multi-cycle continuity.

## Why this didn't surface earlier

The /continue loop's anti-pattern rules (`LOOP.md` §"Anti-patterns
observed in past sessions") explicitly flag "Big next task,
natural stop" and "1 op = 1 chunk" failure modes — but the
EH foundation atoms didn't trip either: each was small,
test-gated, and observably correct. The chain pattern (13×
small architectural atoms that don't converge to an end-to-end
behavior change) is not captured by the existing rules.

The chain failed via incremental satisfaction: each cycle's
1-file size felt right; each cycle's tests felt right; each
cycle's commit message felt productive. Only at cycle 13 — when
the next atom needed to go deeper into emit.zig's dispatch flow
than fits in one cycle — did the chain-level pattern surface.

The architectural_spike.md 3-cycle cap is the closest existing
guard; it fires when a single chunk burns 3 cycles without
measurable progress. The foundation chain shipped measurable
progress each cycle (file landed + tests pass), so the cap
didn't fire even after 13 cycles.

## Implication

Consider adding to `.claude/rules/architectural_spike.md` (or as
a new rule):

> When N consecutive cycles ship architectural-typed chunks on
> the same track without moving any end-to-end behavior signal
> (spec test pass count, fixture green count, real-world fixture
> green count, lint counts), the (N+1)th cycle should pause and
> survey whether the next atom converges on observable behavior
> OR is another foundation block. If foundation, pivot to a
> different track OR file a spike for the integration design
> pass.

The threshold N is calibration-dependent. For Phase 10 EH the
foundation chain reached N=13 before this observation surfaced.
A reasonable starting threshold for the rule: N=5 (= one work
week of autonomous cycles at a 1/day cadence; long enough that
the loop has shipped substantial work; short enough that the
integration story can be re-evaluated).

## Related

- `.claude/rules/architectural_spike.md` — single-cycle "no
  observable behaviour" rule (this lesson extends the time axis).
- `.claude/skills/continue/LOOP.md` §"Anti-patterns observed in
  past sessions" — the "1 op = 1 chunk" and "Big next task,
  natural stop" entries.
- §10.E codegen chunks 1..4b + N-4 (the 13-cycle source data).
- ADR-0114 (the EH design ADR that the foundation atoms
  realised; integration still pending).
