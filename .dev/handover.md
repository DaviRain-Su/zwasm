# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `bf0ac870` — fix(p10): memory.grow respects pages_max +
  runner runs void-result asserts. Two narrow fixes (interp grow
  cap, runner void-result branch + invokeInstanceVoid helper)
  moved 19 memory64 directives green.
- **ROADMAP §10 progress**: 7/13 DONE, 4 IN-PROGRESS, 2 Pending.
- **Active debt rows**: 18 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows. (D-191 filed this
  cycle for the wast baker action-directive drop.)

## Spec runner observable (HEAD `bf0ac870`)

```
[memory64           ] return=337 (pass=336 fail=1  ) trap=205 (pass=205 fail=0  ) invalid=83  (pass=83  fail=0) exception=0
[tail-call          ] return=31  (pass=31  fail=0  ) trap=0   (pass=0   fail=0  ) invalid=10  (pass=10  fail=0) exception=0
[exception-handling ] return=34  (pass=0   fail=34 ) trap=2   (pass=0   fail=2  ) invalid=7   (pass=6   fail=1) exception=4 (pass=0 fail=4)
[gc                 ] (no corpus — D-179 wabt)
[function-references] return=0   (pass=0   fail=0  ) trap=0   (pass=0   fail=0  ) invalid=12  (pass=12  fail=0) exception=0
total: return pass=367 fail=37; trap pass=205 fail=2; invalid pass=111 fail=1; exception pass=0 fail=4
```

memory64 return 336/337 (one residual = test_redundant_load,
blocked by D-191 baker gap). memory64 corpus effectively closed
this cycle. EH still 0/34 — separate 10.E bundle.

Recent commits this resume:
- `bf0ac870` fix — memory.grow pages_max + void-result asserts (+19).
- `f50fb629` chore — close D-190; retarget handover at residual 8.
- `1e5ceb71` fix — spec runner shares Instance per module block (D-190 close).
- `b43cb04a` chore — retarget; file D-190.
- `60549a3e` fix — memory.size/grow interp idx-type-width result.

## Active task — EH module-compile gap (10.E scope)

memory64 corpus is closed save 1 baker-blocked case (D-191). Next
front: EH 33+2+4 = 39 directive fails all root at the missing
`try_table` op validator + interp dispatch. This is the 10.E
bundle (multi-cycle). Per the bundle vs debt rule, opening a
formal bundle is appropriate since we'd re-arm /continue to work
on it next cycle.

Alternative bite-sized cycles inside 10.E: D-191 (extend baker to
emit invoke actions) is a single-cycle fix that closes the last
memory64 directive cleanly, but it's also a runner refactor of
similar scope to D-190. Pick D-191 next cycle as a quick close
before opening the larger 10.E bundle.

## Next sub-chunk candidates (names only)

- **D-191 baker action-directive emit** — small, bounded; closes
  memory64 residual 1 + unblocks future state-sequence corpora.
- **10.E EH module-compile gap** — multi-cycle bundle: `try_table`
  validator + interp dispatch substrate. 39 directive fails root here.
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
