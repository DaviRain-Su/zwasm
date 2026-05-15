# Phase 9 完備 substrate re-examination gate

> **Hard human-in-loop gate** before §9.12 flips and Phase 10
> prep work begins. The autonomous `/continue` loop **must stop**
> when it reaches this row and surface to the user; no
> `ScheduleWakeup` fires until the audit deliverables below are
> collaboratively cleared.
>
> Anchored from ROADMAP §9.9 row 9.12 (`🔒` + this doc) and
> `.claude/skills/continue/SKILL.md` §"Exception — hard
> human-in-loop transition gates" generic carve-out (Detection
> rule fires on `🔒` + `phase*_*.md` reference).
>
> Filed per **ADR-0062** (2026-05-16). Existing Phase 10 entry
> gate (Track D prep, was 9.12) is renumbered to 9.13 — this
> audit precedes it.

## Why this gate exists

Phase 9 closes with **Wasm 2.0 100% PASS** on Mac aarch64 +
OrbStack x86_64 + windowsmini, achieved by direct editing of
exhaustive `switch (ZirOp)` blocks across `src/ir/lower.zig`
/ `src/validate/validator.zig` / `src/engine/codegen/arm64/
emit.zig` / `src/engine/codegen/x86_64/emit.zig`, plus point
fixes in the spec_assert harness. This trajectory ships PASS
count but **diverges from ROADMAP §4.5 / §4.6** which prescribe
per-op handler modules registered into a central
`DispatchTable`, with build-time `-Dwasm=` / `-Denable=` flags
selecting which modules compile in.

The concrete drift is in ADR-0062 §"Context" — five enumerated
facts about `WasmLevel`'s dead use, `DispatchTable`'s null
init, `feature/*/register.zig` no-op stubs,
`instruction/wasm_X_Y/*/<cat>.zig` dead writes, and switch-arm
direct edits as the actual binding mechanism.

This gate forces a stop **before** Phase 10 starts adding Wasm
3.0 features (GC, EH, tail-call, memory64), so the substrate
on which they land is the correct one — not the inherited
500-arm-switch shape.

## Project value axes (user-stated 2026-05-16)

The audit must keep all five axes in mind and choose
architecture that maximises them jointly:

| Axis              | Translation                                              |
|-------------------|----------------------------------------------------------|
| 構造的にきれい    | Source organisation by op / by feature is navigable      |
| 高速              | Hot paths (interp inner loop; per-op JIT emit dispatch) free of avoidable indirection |
| 小さい            | `-Dwasm=1.0` build excludes 2.0/3.0 code (binary + comptime) |
| 教科書的          | A reader can pick up one file and understand one op family |
| 実用的            | Hot ABI invariants (ZirOp slot count, dispatch shape) survive future Wasm proposal merges without further substrate redesign |

**Anti-axis**: "ship now" cost. Per user directive: cost is
not a constraint.

## Open questions (resolve via this gate)

These four questions surfaced in the 2026-05-16 design
discussion. Each must have a decided answer before the gate
closes:

### Q1 — Trigger mechanism (resolved)

- **Resolved by ADR-0062**: this gate is row 9.12 (new),
  separate from Phase 10 entry gate (now 9.13). Track D
  prep and substrate audit are not merged.
- **No further action**.

### Q2 — Re-examination scope

- Sub-questions:
  - Does the audit reopen ROADMAP §2 P13 ("Day-one ZIR sized
    for full target") — i.e. should the `ZirOp` enum itself be
    feature-conditioned at comptime?
  - Does the audit reopen P14 ("Pervasive build-time
    if-branching") — i.e. is the wording too broad? Does
    `if (comptime build_options.feature_X)` count as
    forbidden? (Suggested in 2026-05-16 thread: P14 sharpens
    to "no runtime if-branching on feature flags; comptime is
    fine".)
  - Does the audit reopen §4.5 (dispatch-table architecture)
    — is the function-pointer table the right abstraction at
    all?
- **Required deliverable**: explicit decisions (Accept /
  Amend / Reject) for §2 P13, §2 P14, §4.5, §4.6, recorded in
  this doc's "Decisions" section below.

### Q3 — Architecture spike (the core technical question)

Three hypotheses (from 2026-05-16 thread):

- **A (Complete §4.5 as written)**: Function-pointer
  `DispatchTable` × 4-5 axes per ZirOp, populated at startup
  by `registerAll(*DispatchTable)` from enabled feature
  modules.
- **B (Comptime-gated switch)**: Keep current exhaustive
  `switch (ZirOp)` arms; wrap each Wasm-2.0+ / feature-X arm
  in `if (comptime build_options.feature_X) { ... } else {
  return Error.UnsupportedOpForBuildLevel; }`. Dead-code
  eliminated at -Dwasm=1.0 build.
- **C (Hybrid: per-op file + comptime-generated inline-switch)**:
  Each op lives in `src/instruction/wasm_X_Y/<op>.zig`
  exporting `pub const handlers = .{ .feature = ..., .validate
  = fn, .lower = fn, .arm64 = fn, .x86_64 = fn, .interp = fn };`.
  At comptime, a `dispatch_emit_arm64` builder uses
  `inline for (collectEnabledOpHandlers()) |h| { if (op == h.op)
  return h.arm64(...); }` — switch performance, per-op-file
  source organisation.

- **Required deliverable**: a `private/spikes/substrate_dispatch/`
  directory with N spikes (one per hypothesis), each measuring:
  - Emitted machine code shape (JIT compile pass) — verify
    inline-switch is comparable to direct switch, and
    function-pointer indirect call is N cycles slower.
  - Zig comptime compile cost (especially for hypothesis C
    with `inline for` over hundreds of ops).
  - Source organisation outcome (1 module touched per op vs
    N modules touched).
  - Build size with `-Dwasm=1.0` (does the disabled feature
    actually drop out of the binary?).
- An ADR (0063 or similar) **Accepted** with the chosen
  hypothesis + measurement evidence + rejection reasons for
  the others.

### Q4 — Boundary of audit vs. implementation

- The audit gate's deliverable is **decision + ADRs**, not
  implementation. Implementation lands in Phase 10 sub-rows.
- But: minimal proof-of-concept may be wanted. The audit may
  ship a single representative op converted to the chosen
  architecture (e.g. `i32.add`) as a working reference.
- **Required deliverable**: explicit scope statement in this
  doc's "Outcome" section.

## Deliverables required to close the gate

1. **ADR-0063** (or sequential) recording the chosen
   architecture (Q3). Accepted status.
2. **ADRs amending or affirming**: §2 P13, §2 P14, §4.5,
   §4.6 (Q2). Each gets explicit Accept / Amend / Reject.
   May be one combined ADR or multiple — at audit author's
   discretion.
3. **Optional `private/spikes/substrate_dispatch/`** with
   spike experiments and measurements supporting Q3's
   choice.
4. **Phase 10 plan amendment** (if substrate redesign
   requires it). The existing `.dev/phase10_transition_gate.md`
   may need its first-row scope adjusted to "substrate
   refactor lands before Wasm 3.0 feature work" — or split
   into a new Phase 9.5 implementation phase.
5. **This doc's "Decisions" section** filled in with
   the four Q resolutions.
6. **Audit summary** at the top of this doc — a 5-10 line
   abstract for future readers.

## Decisions (fill at gate close)

> Filled by the user-led review session. Each Q gets an
> explicit answer + cross-reference to the relevant ADR.

### Q2 — Scope decisions

- **P13** (ZirOp enum sized for full target):
  - [ ] Accept as-is
  - [ ] Amend (text below)
  - [ ] Reject (text below)
  - ADR ref:
- **P14** (no pervasive build-time if-branching):
  - [ ] Accept as-is
  - [ ] Amend (text below)
  - [ ] Reject (text below)
  - ADR ref:
- **§4.5** (dispatch-table feature modules):
  - [ ] Accept as-is
  - [ ] Amend (text below)
  - [ ] Reject (text below)
  - ADR ref:
- **§4.6** (build flags `-Dwasm=` / `-Denable=`):
  - [ ] Accept as-is
  - [ ] Amend (text below)
  - [ ] Reject (text below)
  - ADR ref:

### Q3 — Architecture decision

- [ ] Hypothesis A — DispatchTable function-pointer
- [ ] Hypothesis B — Comptime-gated switch
- [ ] Hypothesis C — Hybrid (per-op file + inline-switch)
- [ ] Hypothesis D — Other (specify)
- ADR ref:
- Spike evidence path(s):

### Q4 — Audit boundary

- [ ] Decision-only (implementation in Phase 10)
- [ ] Decision + minimal POC (one op)
- [ ] Decision + full skeleton (all ops, no behaviour change)
- ADR ref:

## Outcome (audit summary — fill at close)

> 5-10 line abstract for future readers.

## Reference

- **ADR-0062** — this gate's authoring decision.
- **ADR-0023** — Zone layering + §4.5 origin.
- **ADR-0041** — SIMD-128 design framing (precedent for
  shape-as-variant ZirOp / feature-register pattern that the
  audit will re-examine).
- 2026-05-16 chat discussion thread.
- ROADMAP §2 P13, P14; §4.5, §4.6; §14 forbidden list;
  §18 amendment policy.
