# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `eccab477` — chore(p10): ADR-0122 **D-193 FULLY
  DISCHARGED** — linker 610/650 is_tail fixup tests portable via
  comptime per-arch byte shape (10.G cycle 47). Mac aarch64
  `zig build test` exit 0 + lint clean. cycle 46 (`347f1fa7`) verified
  green on Linux x86_64 (ubuntu `OK`). cycle 47 pending ubuntu kick —
  Step 0.7 next cycle reads `/tmp/ubuntu.log`.
- **D-193 closed**: all ~23 original Mac-aarch64-only test gates
  cleared over cycles 41/43/44/45/46/47 (debt row → Discharged). The
  D-180-hazard coverage gap (Mac-only executing tests hiding Linux
  x86_64) is gone. 0 `skip.blocker(.@"D-193")` sites repo-wide.
- **Active debt rows**: 17 — all `blocked-by:` with named barriers.
  Zero `now`-status rows.
- **No Active bundle** yet — opening 10.R next (see below).

## Active task — pivot to ROADMAP §10 row 10.R (function-references)

The D-193 test-gate stream (cycles 41-47) is complete. Re-grounded in
ROADMAP §10: open feature rows are 10.M / 10.R / 10.TC / 10.E / 10.G /
10.P. Frontier analysis:
- memory64 (10.M) + tail-call (10.TC) spec corpora already pass
  (337/337, 31/31). 10.TC's last piece return_call_ref is **blocked
  by 10.R** (D-186). 10.E blocked (D-188/D-192: exnref ValType ADR +
  cross-module register). 10.G op-corpus D-179-blocked (wabt 1.0.41+).
- **10.R is the unblocked high-leverage pick**: `ref.as_non_null` /
  `br_on_null` / `br_on_non_null` / `call_ref` / `return_call_ref` +
  `(ref $sig)` typed funcref typing; `feature/function_references/`.
  GC prerequisite (MVP.md:14-22) AND unblocks 10.TC return_call_ref.
  Its spec corpus bakes green (per D-179).

**NEXT chunk — 10.R Step 0 survey** (Explore subagent, then open a
bundle): (1) locate the governing ADR — function-references typing is
likely folded into ADR-0116 (RTT/typed-ref/i31) or ADR-0115; confirm
whether `(ref $sig)` Value shape + validator typing is ADR-covered or
needs a new ADR (ROADMAP §4 ValType deviation → file first if
uncovered). (2) Survey v1 `function_references` + wasmtime +
wasm-tools for the typed-funcref Value shape, null-typing, and
br_on_null/br_on_non_null branch typing. (3) Identify the smallest red
test — likely `ref.as_non_null` (traps on null, identity otherwise) or
`br_on_null` validator typing. Then open `## Active bundle` for 10.R
with cycles-remaining + exit-condition (function-references spec
return/trap fixtures run, not just invalid=12).

## Trivial follow-up (2-min, opportunistic)

- `src/test_support/skip.zig` `Blocker.@"D-193"` enum variant is now
  unused (0 call sites). Remove it when next touching skip.zig — the
  pre-commit gate passed with it present, so not urgent.

## Larger §10 work (blocked / later)

- **10.M memory64** — spec passes; remaining = multi-memory
  (`memories: []MemoryInstance`) + clang_wasm64 realworld (D-179).
- **10.E EH** — blocked: exnref ValType (ADR §4 deviation) + runner
  cross-module register (D-188 / D-192).
- **10.G WasmGC op-corpus** — D-179-blocked (wabt 1.0.41+). Substrate
  landed end-to-end (parse + struct/array ops + β mark-sweep + roots).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (HEAD `96a17d5a`; gate-only cycles unchanged)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(fail2) exception=4(fail4)
[function-references] invalid=12 (all pass)   <- return/trap fixtures not yet run (10.R target)
```

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- D-188 / D-192 — EH blocked on exnref ValType + cross-module register.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0122 (test skip categorization) — D-193 discharge complete.
- ADR-0115 / ADR-0116 (GC heap / roots+RTT+i31) — check for
  function-references typing coverage during 10.R survey.
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- ROADMAP §10 rows 10.R / 10.TC; `.dev/phase_log/phase10.md`.
