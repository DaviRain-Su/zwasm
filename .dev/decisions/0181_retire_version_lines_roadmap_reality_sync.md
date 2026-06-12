# ADR-0181 — Retire version lines from the ROADMAP; sync §1.2/§1.3/§3/§7/§8 to reality

> **Doc-state**: ACTIVE
> Status: Accepted (2026-06-13, user-approved direction)

## Context

The ROADMAP's mission/scope sections were written at project start and
framed future work as **version lines** ("v0.2.0 line", "deferred to
v0.2.0+", "post-v0.1.0"). Two things have overtaken that framing:

1. **ADR-0156** made releases a manual, user-only act with NO loop-side
   release construct — the loop pursues 完成形 indefinitely. A "version
   line" no longer gates anything; the only real lines are the
   correctness floor (§1.2) and the inviolable principles (§2).
2. **Reality moved past the deferral list.** Phase 17 (user-unblocked,
   ADR-0168/0170) shipped atomics / wide-arith / custom-page-sizes /
   relaxed-SIMD, and the Component Model + WASI Preview 2 campaign is the
   active NOW-pointer with real Rust/Go components running e2e, a
   structural validator (corpus 105 pass), a native P2 host (fs / stdio /
   clocks / random / poll), and a TCP-client sockets host (ADR-0180).
   §1.3, §3.3, §7 and §8 still describe all of this as "deferred to
   v0.2.0".

A 2026-06-13 user review re-stated the ideal the ROADMAP must encode:
full-featured · lightweight · beautiful design · easy to use ·
fast-start/fast-exit workloads (single-pass; losing to multi-tier
optimisers is accepted) · 100% official spec + industry-standard usage ·
no crashes, GC/JIT edge cases correct · usable from C API (same shape as
other runtimes) and Zig API. This matches §1.2's 完成形 bar; the stale
version framing does not.

## Decision

1. **Retire version lines as planning constructs.** §1.3 is reframed as a
   *capability backlog* (no version gates); §3.3's "Deferred to v0.2.0+"
   becomes "Deferred (demand-driven)". Versions remain only as the
   user's manual tagging vocabulary (ADR-0156 unchanged).
2. **Promote the active capabilities into the §1.2 correctness floor**:
   Component Model + WASI 0.2 at **wasmtime-equivalent** conformance
   (ADR-0170) join the floor table (campaign in progress = the floor is
   the bar being driven to, like every other row was while its phase ran).
3. **Single-pass is permanent, not "re-evaluate later".** The optimising
   tier moves from §3.3 (deferred) to §3.2 (out of scope permanently),
   resolving the latent contradiction with ADR-0153's inviolable P3/P6
   and matching the user-stated positioning (fast-start workloads;
   multi-tier optimisers may win on throughput).
4. **§7/§8 reality fixes**: the atomics INSTRUCTION SET is shipped
   (single-threaded semantics); what stays deferred is shared-memory
   threaded execution. WASI strategy reflects the native P2 host (no
   adapter module; P1 facilities reused host-side) and the sockets state.
5. **Lightweight gets a measurement** (the weakest-instrumented axis of
   the ideal): a debt row (D-320) tracks adding binary-size /
   JIT-poll-code-size series to the bench history so "lean-but-complete"
   is observed, not assumed.

## Alternatives rejected

- **Keep version lines as informal milestones** — they keep generating
  drift ("deferred to v0.2.0" rows that are actually DONE) and imply a
  release cadence ADR-0156 abolished.
- **Drop the optimising tier to "watch" instead of permanent-out** —
  contradicts ADR-0153's inviolable single-pass principles; a future
  reversal would be a full §2 amendment anyway, which §3.2 wording does
  not prevent.

## Consequences

- ROADMAP §1.2 floor table gains CM + WASI-0.2 rows; §1.3 retitled
  "Capability backlog (no version lines)"; §3.3 pruned to what is
  genuinely not built (threaded execution, stack switching / WASI 0.3,
  shared-everything threads, RISC-V / s390x); §3.2 gains the optimising
  tier; §7/§8 updated.
- D-320 (note): binary-size + poll-code-size measurement series.
- Phase 17's widget row keeps "Capability work, NOT a version march" —
  now consistent with §1/§3.
