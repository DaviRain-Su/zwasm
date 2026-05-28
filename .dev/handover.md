# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.M-D195b cycle 77 — `Linker.defineGlobal` +
  spectest globals (i32/i64/f32/f64) pre-register. D-196(a)
  partial discharge (host-side standalone Global construction
  still v0.2). Spec runner `[multi-memory] return=407 (pass=382
  fail=25) trap=238 (pass=237 fail=1)`. Substrate change: data0.3/5
  transitioned from UnknownImport → InstantiateFailed (cross-
  instance global resolves; downstream gap = init-expr global.get
  eval).
- **D-188 / D-194 / D-195(c) DISCHARGED** earlier. **D-195(b)
  memory + func + spectest stubs + globals WIRED** (cycles 71-77).
  Active debt rows: 17 — all `blocked-by:`; zero `now`.

## Active bundle

- None.

## Active task — cycle 78: pivot to 10.E EH runtime path

10.M autonomous portion is substantially complete (the substrate
is now memory + cross-instance memory imports + cross-instance
funcs + cross-instance globals + spectest host stubs). Remaining
10.M gaps are upstream-corrupted fixtures + obscure init-expr
features. The next highest-yield §10 row is **10.E** —
`[exception-handling] return=34(fail34) trap=2(fail2) exception=4(fail4)`.
Validator side spec-correct as of cycle 61; runtime EH dispatch
is the remaining work.

Cycle 78 candidates:

1. **10.E EH runtime — bake try_table.0 instantiate fixture** —
   try_table.0.wasm currently fails `InstantiateFailed` (per
   D-192). The validator now passes it; the runtime needs tag
   section processing + throw/catch dispatch wiring. Multi-cycle
   bundle (3-5 cycles likely).
2. **Init-expr global.get support** — small extension to
   `runtime/instance/instantiate.zig::evalConstMemAddrExpr`
   accepting `0x23 globalidx` (global.get init-expr form) +
   pulling the value from `rt.globals`. Closes data0.3/5
   InstantiateFailed; +2 instantiate counters. 1 cycle.
3. **D-178 full discharge — host-side standalone Global
   construction** — v0.2 c_api scope per D-178 (defer).

Cycle 78 picks (2) — narrow scope, builds on cycle 77's spectest
globals substrate, closes a few more fixture instantiate-fails.

## Larger §10 work (blocked / later)

- **10.M memory64 multi-memory** — autonomous substantially done.
  D-196 tail covered by runner allowlist or upstream fix.
- **10.E EH** — validator spec-correct (cycle 61); runtime EH
  dispatch is the next bundle (cycle 79+).
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-77; counts unchanged)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[multi-memory       ] return=407(pass=382 fail=25) trap=238(pass=237 fail=1)
                      invalid=2(pass=2) malformed=2(pass=2) skip=56
[wasm-3.0-assert    ] assert_return pass=750  assert_trap pass=442  assert_invalid pass=120 fail=0
```

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref +
  return_call_ref impl + typed-ref parser (D-195 sub-gap a).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- D-178 — narrow extension landed cycle 77 (defineGlobal); full
  host-side Global construction surface remains v0.2.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0111 (memory64 + multi-memory design).
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-29-gate-tail-vs-exit-code.md`.
- ROADMAP §10 row 10.M / 10.E; `.dev/phase_log/phase10.md`.
