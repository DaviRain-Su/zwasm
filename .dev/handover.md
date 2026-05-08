# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — D-054 + D-055 + 9 other rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: hoist-branch-targets-as-pc, regalloc, coalescer).
5. `.dev/decisions/0031_zir_hoist_pass.md` (D-053 root-cause amend per 8a.6).
6. `.dev/optimisation_log.md` (F/R/O ledger; 8b adoption discipline).

## Current state — Phase 8 / §9.8b / 8b.2-c landed (LIFO free-pool refactor); 8b.2-d **NEXT**

§9.8b / 8b.2-c lands the LIFO free-pool refactor of
`regalloc.compute`. **Discovery** during implementation:
the prior busy-mask scan already implemented slot reuse on
dead vregs (the `earlier.last_use_pc > r.def_pc` check is
an inline reuse mechanism). The refactor's value is
algorithmic (no per-vreg `@memset` over 4 KiB) + Phase 15
substrate (free-pool pops as same-slot reuse events for
the coalescer per ADR-0035 + ADR-0036). Bench-delta 0% by
construction.

ADR-0037 amended with Revision row 2 capturing the
discovery. Lesson `2026-05-09-greedy-local-already-does-
reuse.md` codifies "read the actual code before accepting
upstream framing" rule. **Pivot for 8b.2-d**: real bench-
delta wins migrate to **class-aware allocation** (D-036
§option-b — current `regalloc.zig:131-133` notes
"Tighter accounting lands when the allocator becomes
class-aware"); requires ADR-0038 before implementation.

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; §9.8a complete
(8a.1-8a.6 [x]); §9.8b / 8b.1 [x] (per ADR-0036);
§9.8b / 8b.2-a (survey) + 8b.2-b (ADR-0037) + 8b.2-c
(refactor) [x]; **§9.8b / 8b.2-d NEXT** — class-aware
allocation per D-036 §option-b + ADR-0038. Phase 8 残
rows = 8b.2-d + 8b.2-e + 8b.3 + 8b.4 + 8b.5 + 8b.6.

## Active task — §9.8b / 8b.2-c: Slot reuse implementation **NEXT**

Per ADR-0037 (Status: Accepted), **Option 1 (slot reuse on
dead vregs)** is the 8b.2 MVP. Free-slot pool (LIFO/stack)
returned at `liveness.last_use_at_pc[pc]`, popped at
`liveness.def_at_pc[pc]`. ABI preserved (`Allocation { slots,
n_slots }` unchanged). Options 2 (live-range splitting) +
Option 3 (full SSA linear-scan) deferred to Phase 15
alongside coalescer detection lift (ADR-0036).

8b.2-a Step 0 survey complete (`private/notes/p8-8b2-regalloc-
survey.md`, 496 lines, gitignored). Five codebases surveyed
(zwasm v1 W43-W45 + W54 post-mortem; regalloc2;
wasmtime/cranelift; wasmtime/winch; wasmer singlepass).

Three divergences anchored to project principles:
1. No parallel-move insertion (P6 + ADR-0035) — coalesce-time.
2. Straight-line liveness only (P3 + P6) — full CFG to Phase 14+.
3. Slot-id ABI stability (ADR-0018 + ADR-0035) — `slots[]`
   unchanged.

Suggested chunk plan (8b.2):

| #     | Description                                                            | Status   |
|-------|------------------------------------------------------------------------|----------|
| 8b.2-a | Step 0 survey across regalloc2 + cranelift + winch + wasmer + v1 W54 post-mortem | [x] (`8381dfb`) |
| 8b.2-b | ADR-0037 design framing — Option 1 slot-reuse MVP (later amended w/ Revision 2 noting current allocator already implements reuse) | [x] (`8381dfb`; amended this commit) |
| 8b.2-c | LIFO free-pool refactor of `regalloc.compute`; bench-delta 0% (semantic equivalence with prior busy-mask); Phase 15 substrate | [x] (this commit) |
| 8b.2-d | Class-aware allocation per D-036 §option-b — needs ADR-0038 first; tighter spill-frame accounting when GPR + FP vregs share id space | **NEXT** |
| 8b.2-e | 3-host gate; close 8b.2 [x] with bench-delta in commit body | [ ] |

After 8b.2: 8b.3 (AOT skeleton), 8b.4 (≥10% aggregate
exit; absorbs 8b.1 + 8b.2 + 8b.3 contributions), 8b.5
(Phase 8 boundary audit), 8b.6 (open §9.9).

## Coalescer scaffolding (8b.1 [x] artefacts — for Phase 15 reference)

Surface preserved for Phase 15 detection lift:

- `src/ir/coalesce/pass.zig` — pass module + `run` shape +
  `isCoalesceCandidate` (MVP catalogue: `local.tee` /
  `local.get` / `local.set` / `select`) + `deinitArtifacts`.
- `src/ir/zir.zig` — `CoalesceRecord` + `func.coalesced_movs`
  slot.
- `src/engine/codegen/shared/compile.zig` — pipeline
  placement between regalloc and emit.
- `private/notes/p8-8b1-coalescer-survey.md` — Step 0
  survey across cranelift / wasmtime / regalloc2 / wasm3 /
  v1 zwasm (gitignored).
- ADR-0035 (post-regalloc slot-aliasing design) + ADR-0036
  (scope downgrade rationale).

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-054** (`blocked-by: separate investigation`) — OrbStack-
  only; independent of D-053. Likely Rosetta JIT-emulation
  interaction or Linux-x86_64-only path.
- **D-055** (`blocked-by: D-052 + emit_test_*.zig migration`) —
  x86_64 prologue inject deferred (sentinel ARM64-only).
- 9 `blocked-by:` rows — D-007 / D-010 / D-016 / D-018 / D-020
  / D-021 / D-022 / D-026 / D-028 / D-052; barriers all hold.

D-053 closed at `2e0022c` (was promoted to ROADMAP row §9.8a /
8a.5).

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
