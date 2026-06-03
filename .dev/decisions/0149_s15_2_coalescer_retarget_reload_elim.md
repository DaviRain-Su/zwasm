# 0149 — §15.2 re-targeted: slot-alias coalescing has ~0 headroom in v2's spill model → redundant spill-reload elimination

- **Status**: Accepted (2026-06-04; autonomous-with-ADR per default posture + deviation-watch §18.2)
- **Date**: 2026-06-04
- **Author**: claude (autonomous, /continue bundle 15.2-coalescer-detection)
- **Tags**: Phase 15, perf, coalescer, regalloc, emit, spill, ADR-0036, W54
- **Amends**: ROADMAP §15.2 row (mechanism); ADR-0036 (the §9.8b coalescer scaffolding
  premise); ADR-0035 (candidate-op catalogue). Supersedes the slot-alias mechanism.

## Context

§15.2 was scaffolded (ADR-0035/0036, §9.8b/8b.1) as a **post-regalloc slot-alias
coalescer**: detect a MOV-shaped op where `slots[src_vreg]==slots[dst_vreg]` and the
dst is dead-after, then elide the MOV. The design note (`p8-8b1-coalescer-survey.md`)
flagged in its own option (a) that v2's deterministic slot assignment might mean "most
same-slot MOVs never occur."

A deep structural read of the ACTUAL emit (this turn) confirms that warning conclusively:

- **The gpr spill helpers already elide all reg-resident moves**
  (`src/engine/codegen/arm64/gpr.zig`): `gprStoreSpilled` reg-case is `{}` (no store);
  `gprLoadSpilled` reg-case returns the physical register directly (no load);
  `gprDefSpilled` reg-case returns the register. So a register-resident vreg emits
  ZERO load/store movs — the optimum.
- **Spilled vregs do only necessary LDR/STR**; there is no redundant same-slot copy.
- **Locals and spill slots are SEPARATE frame regions** (`local_base_off` vs
  `spill_base_off`, `arm64/emit.zig:910-1055`) — `local.get/set/tee` move between two
  distinct regions, never slot-to-same-slot.
- **v2 emits NO vreg-to-vreg MOVs at all** — values flow load→compute→store; there is
  no reg-to-reg copy op for the slot-alias detector to fire on.

⇒ the slot-alias coalescer (`src/ir/coalesce/pass.zig`) would detect **nothing**
(~0 redundant movs). The scaffolded mechanism cannot reach §15.2's ≥5% target — not
because the target is wrong, but because the redundancy it targets is structurally
absent in v2's spill-everything single-pass model.

## Decision

**Re-target §15.2 from slot-alias MOV coalescing to redundant spill-RELOAD
elimination** — the mov-reduction opportunity that DOES exist in v2's model.

A **spilled** vreg used N times re-emits `gprLoadSpilled` (an `LDR` from its slot) on
EACH use. When the value is still resident in a staging register from a prior load and
that register has not been clobbered in between, the subsequent `LDR`s are redundant.
Caching "which vreg currently lives in which staging reg" during emit and skipping the
reload is the v2-appropriate optimisation. It is emit-local (does NOT change regalloc
slot assignment), so it carries LOWER W54 risk than slot-aliasing (it removes provably-
redundant loads without altering spill timing).

The slot-alias coalescer scaffolding (ADR-0035/0036) is left **dormant** (the no-op
`coalesce.pass` + `CoalesceRecord` stay, deinit-clean) rather than ripped out (churn);
its module doc is marked superseded by this ADR.

## Rejected alternatives

- **Implement the slot-alias coalescer anyway** — it provably detects nothing
  (evidence above); shipping a no-op pass that chases a vacuous ≥5% is dishonest.
- **Vacate §15.2's perf target entirely / fold into §15.3** — the perf goal is valid;
  only the MECHANISM was wrong. Redundant-reload elimination is a real, distinct lever
  from §15.3's allocation-quality work, so §15.2 stays a standalone task.
- **Call-arg / block-merge coalescing** — the only sites with reg-to-reg-ish movs, but
  W54 burned exactly the call-site path (cohort/spill-timing) and they are rare in
  loop-heavy fixtures; not the ≥5% lever. Conservative-bail territory.

## Consequences

- §15.2 stays `[ ]`, mechanism re-scoped. **First step is empirical**: measure the
  redundant-reload headroom on loop-heavy fixtures (fib_loop/nestedloop/sieve) BEFORE
  implementing — if the spilled-vreg multi-use frequency is too low for ≥5%, this ADR
  is revisited (the elimination may instead land as a smaller gain folded into §15.P
  aggregate parity).
- §15.3's "combined coalescer + class-aware ≥10%" exit (ROADMAP) no longer has a
  slot-alias-coalescer component; the combined target now rests on class-aware
  allocation + redundant-reload elim + SIMD (§15.4), validated in aggregate at §15.P
  vs v1 main.
- W54 lesson still governs: emit-stream change → test Mac aarch64 FIRST, differential
  suite (spec+realworld both arches) is the correctness guard, conservative bail across
  call sites + branch targets (a staging-reg cache MUST invalidate at every call and
  branch target).

## Revision (2026-06-04) — measured: headroom < target → §15.2 folded into §15.P

The empirical reload-headroom measurement (throwaway gpr.zig/fp.zig spill counters via
`zwasm run --engine jit`, reverted) lands the "small" branch decisively:

| fixture | spill_loads | spill_stores | redundant_adjacent_loads | total_instrs | redund_adj/total |
|---|---|---|---|---|---|
| tinygo/fib_loop | 272 | 246 | 203 | 9216 | **2.2%** |
| shootout/nestedloop | 258 | 233 | 258 | 17905 | **1.4%** |
| shootout/sieve | 258 | 233 | 258 | 17953 | **1.4%** |

Total spill traffic (loads+stores) is **2.7–5.6%** of all emitted instructions — a strict
UPPER BOUND on any spill-mov optimiser. The adjacent-round-trip eliminable subset is
**1.4–2.2%** of total instructions. A ≥5% **perf** win is robustly unreachable (perf gain
from killing a `LDR`/`STR` is smaller than its instruction-count share; v2's deterministic-
slot spill-everything emit is already tight on memory traffic).

**Decision**: §15.2 closes — the ≥5%-gated mov-reduction task is empirically unreachable in
v2's emit model (in EITHER the slot-alias OR reload-elim mechanism). The residual
store-then-immediate-reload peephole (real but ~1.5–2% — note the 75–100% redund/load
ratio = a structural def-then-reload pattern) **folds into §15.P** as an opportunistic
peephole, NOT a dedicated bench-gated effort. Phase-15 perf parity rests on §15.3 (class-
aware allocation) + §15.4 (SIMD ports) + the §15.P aggregate vs v1. **General caution**: the
low spill share suggests the regalloc-axis perf tasks (§15.2/§15.3) have less headroom than
the ROADMAP assumed; the larger wins are likely §15.4 SIMD + algorithmic — assess §15.3 on
its own measurement before committing to its ≥3% bar.
