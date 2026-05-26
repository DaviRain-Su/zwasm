# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `60549a3e` — fix(p10): memory.size/grow interp returns
  idx-type-width result. inline `memory0IsI64(rt)` dispatches
  push/pop width on the memory section's idx_type; runtime page-cap
  also lifts for memory64. Two new in-source tests pin both shapes.
- **ROADMAP §10 progress**: 7/13 DONE, 4 IN-PROGRESS, 2 Pending.
- **Active debt rows**: 18 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows. (D-190 filed this
  cycle for the spec-runner architecture issue.)

## Spec runner observable (HEAD `60549a3e`)

```
[memory64           ] return=337 (pass=296 fail=29 ) trap=205 (pass=205 fail=0  ) invalid=83  (pass=83  fail=0) exception=0
[tail-call          ] return=31  (pass=31  fail=0  ) trap=0   (pass=0   fail=0  ) invalid=10  (pass=10  fail=0) exception=0
[exception-handling ] return=34  (pass=0   fail=33 ) trap=2   (pass=0   fail=2  ) invalid=7   (pass=6   fail=1) exception=4 (pass=0 fail=4)
[gc                 ] (no corpus — D-179 wabt)
[function-references] return=0   (pass=0   fail=0  ) trap=0   (pass=0   fail=0  ) invalid=12  (pass=12  fail=0) exception=0
total: return pass=327 fail=62; trap pass=205 fail=2; invalid pass=111 fail=1; exception pass=0 fail=4
```

memory64 return 296 (was 289 last cycle, +7); fail 29 (was 36).
Remaining 29 traced to runner-architecture (D-190) — each
assert_return creates a fresh Instance, so state-dependent
sequences (size → grow → size → load) can't accumulate.

Recent commits this resume:
- `60549a3e` fix — memory.size/grow interp idx-type-width result.
- `747de7df` chore — retarget handover after memory64 data-segment fix.
- `b04a214e` fix — instantiate active data on memory64 (+396 dirs).
- `7d815816` chore — retarget handover at memory64 instantiate gap.
- `ea414cf0` test — pin memory64 instantiate gap at address64.0.

## Active task — EH module-compile gap OR D-190 (runner refactor)

memory64 corpus has hit the runner-state ceiling: further per-op
fixes won't close the 29 residual without D-190's instance-sharing
refactor. Two parallel paths:

(a) **D-190** — refactor wasm-3.0-assert runner to thread one
Instance per `module <path>` block. Multi-cycle (touches runOne
signatures + dispatch loop). Closes memory64 residual 29 + makes
the runner correct for future memory_redundancy64 / memory64.wast
test classes.

(b) **EH module-compile gap** — 33+2+4 EH directive fails all
root at the missing `try_table` op validator + interp dispatch.
Multi-cycle (10.E scope). Each cycle = one architectural sub-step
toward the EH-on-interp path.

Pick (a) next cycle — it's smaller and closes a concrete number
(29 directives) with no upstream/ADR dependency. EH stays the
larger 10.E bundle candidate.

## Next sub-chunk candidates (names only)

- **D-190 runner refactor** — active per above; multi-cycle but
  bounded.
- **EH module-compile gap** — `try_table` op validator + interp
  dispatch substrate. Multi-cycle (10.E scope).
- **D-188 final (try_table.10)** — `catch_all_ref` typing in
  try_table. Blocked-by exnref ValType extension (multi-cycle).
- **10.R-4 / 10.R-5 (call_ref / return_call_ref)** — blocked-by
  D-186 (typed-funcref Value shape ADR).
- **10.G WasmGC** — large multi-cycle bundle.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.
- D-186 — `return_call_ref` blocked-by 10.R-3/4/5.
- D-188 — 1 remaining (try_table.10); blocked-by 10.E validator
  + exnref ValType extension.

## Key refs

- ADR-0017, ADR-0026, ADR-0109, ADR-0111 (memory64 design),
  ADR-0112, ADR-0113 §A, ADR-0114 D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.T /
  10.TC / 10.E / 10.M.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
