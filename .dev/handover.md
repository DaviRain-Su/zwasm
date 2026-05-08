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

## Current state — Phase 8 / §9.8b / 8b.1 closed via ADR-0036; **§9.8b / 8b.2 NEXT**

ADR-0036 (`0036_coalescer_scope_downgrade.md`, Status:
Accepted) formalises 8b.1's scope as scaffolding-only;
concrete detection (operand-stack vreg-numbering simulation
+ emit-side query) deferred to Phase 15 once 8b.2's
allocator reshape exposes natural same-slot sites. ADR-0035
amended with Revision row citing ADR-0036. ROADMAP §9.8b /
8b.1 row updated and flipped `[x]` per §18 (ADR filed
first). The previous resume's §18-caught quiet downgrade
attempt is structurally resolved.

§9.8a closed across 6 commits. **Phase 8a foundation
complete.** §9.8b now opens with 8b.1 closed; remaining
rows = 8b.2 + 8b.3 + 8b.4 + 8b.5 + 8b.6.

直近 commits (latest at top):

- (this commit) chore(p8): close §9.8b / 8b.1 via ADR-0036 —
  scope downgrade + ADR-0035 amend + ROADMAP retarget.
- `e0128c7` chore(p8): annotate §9.8b / 8b.1 sub-rows
  (8b.1-c + 8b.1-d-step1 [x] within row text).
- `b2b47f8` chore(p8): mark §9.8a / 8a.5 [x]; reframe D-054
  as independent.

3-host gate at `34a3ac1`: Mac green, OrbStack 1 known D-054
FAIL only, windowsmini green.

**Phase 8 status**: §9.8 / 8.0-8.4 [x]; §9.8a complete
(8a.1-8a.6 [x]); §9.8b / 8b.1 [x] (per ADR-0036);
**§9.8b / 8b.2 NEXT** — Phase 8 残 rows = 8b.2 + 8b.3 + 8b.4
+ 8b.5 + 8b.6.

Step 5b's `8a.1+8a.2+8a.3 all [x]` trigger satisfied — Phase
8b chunks remain **bench-delta-gated** per ADR-0032 (8b.2
onward; 8b.1's bench-delta requirement is absorbed into
8b.4 aggregate per ADR-0036).

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
| 8b.2-a | Step 0 survey across regalloc2 + cranelift + winch + wasmer + v1 W54 post-mortem | [x] (this commit; survey at `private/notes/p8-8b2-regalloc-survey.md`) |
| 8b.2-b | ADR-0037 design framing — Option 1 slot-reuse MVP; LIFO free-pool; ABI preserved | [x] (this commit; ADR-0037 Accepted) |
| 8b.2-c | Implement free-slot pool in `regalloc.zig`; new unit test for `n_slots = 1` on 3-vreg sequential program | **NEXT** |
| 8b.2-d | Wire into `compile.zig`; bench-delta capture on tinygo/fib_loop + shootout/nestedloop + tinygo/string_ops | [ ] |
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
