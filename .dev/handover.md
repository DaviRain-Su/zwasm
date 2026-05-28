# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 86 — wired `check_rule_paths` /
  `check_skill_descriptions` / `check_doc_state` `--gate` into
  `scripts/gate_commit.sh` via scope flags (RULES_TOUCHED /
  SKILLS_TOUCHED / DEV_MD_TOUCHED). Drift detected by these lints
  now blocks at source commit. cycle-82 audit cohort fully closed
  across cycles 82-86.
- Active debt rows: **18** — all `blocked-by:`; zero `now`.
- Mac aarch64 test-all + lint green at HEAD prior to this chunk
  (52d9c784); ubuntu kick at 52d9c784 confirmed green (Step 0.7
  passed; "failed command:" output is intentional negative-path
  test stderr, not a failure).

## Active bundle

- None.

## Active task — cycle 87: next autonomous chunk

`[wasm-3.0-assert] assert_invalid pass=134 fail=0` unchanged.
Autonomous yield within §10 row 10.E / 10.G / further 10.M
remains gated on ADR-0120 / ADR-0123 Accept or D-179 wabt
upgrade.

Cycle 87 candidates:

1. **Function-references / 10.R bake extension** — survey
   whether any ADR-0123-independent .wast modules remain
   un-baked in the function-references upstream corpus.
   Pure infra cycle.
2. **Wasm 1.0 / 2.0 corpus coverage audit** — alt infra cycle.
3. **debt.md re-evaluation pass** — 12 active rows crossed the
   `Last reviewed > 14d` threshold per cycle-82 §F finding; walk
   each and either re-confirm barrier or note dissolution.

Cycle 87 picks (3) — debt re-eval has direct compounding value
(stale rows hide barrier dissolutions); pure-doc cycle so the
new docs-only short-circuit applies.

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
