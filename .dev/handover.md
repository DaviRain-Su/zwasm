# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 85 — authored
  `scripts/check_rule_paths.sh` + `scripts/check_skill_descriptions.sh`
  (D-058 / D-059 discharged; cycle-82 audit `soon` cohort fully
  closed across cycles 83/84/85: ADR backfill + SKILL.md split +
  lint scripts).
- Active debt rows: **18** — all `blocked-by:`; zero `now`.
- Mac aarch64 test-all + lint green at HEAD prior to this chunk
  (52d9c784); ubuntu kick at 52d9c784 confirmed green (Step 0.7
  passed; "failed command:" output is intentional negative-path
  test stderr, not a failure).

## Active bundle

- None.

## Active task — cycle 86: next autonomous chunk

`[wasm-3.0-assert] assert_invalid pass=134 fail=0` unchanged.
Autonomous yield within §10 row 10.E / 10.G / further 10.M
remains gated on ADR-0120 / ADR-0123 Accept or D-179 wabt
upgrade.

The cycle-82 audit `soon` cohort is now fully closed.
Remaining candidates:

1. **Function-references / 10.R bake extension** — survey
   whether any ADR-0123-independent .wast modules remain
   un-baked in the function-references upstream corpus.
   Pure infra cycle.
2. **Wasm 1.0 / 2.0 corpus coverage audit** — alt infra cycle.
3. **Wire `check_rule_paths.sh` / `check_skill_descriptions.sh`
   `--gate` into `gate_commit.sh` or `audit_scaffolding §G`**
   so future drift is caught at commit time (currently
   informational-only invocation).

Cycle 86 picks (3) — small wiring chunk; closes the cycle-85
lint pair into the gate pipeline so future drift can't sneak
past commit.

## Larger §10 work (blocked / later)

- **10.E EH runtime** — gated on ADR-0120 Accept (exnref ValType).
- **10.M memory64 multi-memory** — autonomous substantially done.
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-81; unchanged by cycle 82)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[multi-memory       ] return=407(pass=382 fail=25) trap=238(pass=237 fail=1)
                      invalid=2(pass=2) malformed=2(pass=2) skip=56
[wasm-3.0-assert    ] assert_return pass=790  assert_trap pass=449  assert_invalid pass=134 fail=0
```

## Open questions / blockers

- ADR-0120 — Status: Proposed; user Accept flip unblocks ~30 EH
  spec directives.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref +
  return_call_ref impl + typed-ref parser (D-195 sub-gap a).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0112 (Tail Call), ADR-0114 (EH), ADR-0120 / 0123 (Proposed).
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-28-gate-tail-vs-exit-code.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
