# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `755d33d2` — fix(p10): wast baker emits invoke action
  directives; runner dispatches them (D-191 close). 3 coordinated
  changes (baker + parser + dispatch) closed the last memory64
  residual. **memory64 corpus is FULLY GREEN: 337/337 return,
  205/205 trap, 83/83 invalid, 0 skip.**
- **ROADMAP §10 progress**: 7/13 DONE, 4 IN-PROGRESS, 2 Pending.
- **Active debt rows**: 17 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows. (D-191 discharged.)

## Spec runner observable (HEAD `755d33d2`)

```
[memory64           ] return=337 (pass=337 fail=0  ) trap=205 (pass=205 fail=0  ) invalid=83  (pass=83  fail=0) exception=0  skip=0
[tail-call          ] return=31  (pass=31  fail=0  ) trap=0   (pass=0   fail=0  ) invalid=10  (pass=10  fail=0) exception=0
[exception-handling ] return=34  (pass=0   fail=34 ) trap=2   (pass=0   fail=2  ) invalid=7   (pass=6   fail=1) exception=4 (pass=0 fail=4)
[gc                 ] (no corpus — D-179 wabt)
[function-references] return=0   (pass=0   fail=0  ) trap=0   (pass=0   fail=0  ) invalid=12  (pass=12  fail=0) exception=0
total: return pass=368 fail=34; trap pass=205 fail=2; invalid pass=111 fail=1; exception pass=0 fail=4
```

memory64 + tail-call + function-references all clean. assert_invalid
111/1 — only try_table.10 left (D-188, exnref). Remaining 40 fails
all from exception-handling (10.E bundle territory).

Recent commits this resume:
- `755d33d2` fix — baker emits invoke action directives (D-191 close, memory64 FULL).
- `c09cc64f` chore — retarget at D-191; file baker debt.
- `bf0ac870` fix — memory.grow pages_max + void-result asserts (+19).
- `f50fb629` chore — close D-190; retarget at residual 8.
- `1e5ceb71` fix — spec runner shares Instance per module block (D-190 close).

## Active task — 10.E EH module-compile gap (bundle candidate)

memory64 fully closed. The remaining 40 spec runner fails (34
return + 2 trap + 4 exception) all root at the missing `try_table`
op validator + interp dispatch in `src/instruction/wasm_3_0/` +
EH-on-interp dispatch substrate. This is multi-cycle 10.E scope;
bundling is appropriate (per bundle vs debt rule, we'd re-arm
/continue to immediately work this next cycle).

Per spike_discipline + architectural_spike rules, the foundation-
atom chain pattern is forbidden (lesson 2026-05-26). Bundle mode
with a named observable exit-condition is the structural defense.

Next cycle opens the 10.E codegen-IT bundle with a specific
exit-condition (try_table.0.wasm compiles + first directive
shape — likely simple-throw-catch — invokes successfully).

## Next sub-chunk candidates (names only)

- **10.E EH module-compile gap (bundle)** — active per above;
  multi-cycle, 40 directives unblock.
- **D-188 final (try_table.10)** — `catch_all_ref` typing. Blocked-by
  exnref ValType extension (multi-cycle).
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
