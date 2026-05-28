# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.M cycle 76 — diagnostic survey of remaining
  multi-memory fails complete. Filed D-196 covering (a) Linker.
  defineGlobal API absence, (b) 7 upstream-corrupted fixtures,
  (c) named-module register-as form. Spec runner unchanged at
  `[multi-memory] return=407 (pass=382 fail=25) trap=238 (pass=237
  fail=1)`.
- **D-188 / D-194 / D-195(c) DISCHARGED** earlier. **D-195(b)
  memory + func + spectest stubs WIRED** (cycles 71-75).
  D-196 filed cycle 76 (10.M tail; D-178-territory). Active
  debt rows: 17 — all `blocked-by:`; zero `now`.

## Active bundle

- None.

## Active task — cycle 77: pivot to 10.E EH runtime path

10.M autonomous portion is substantially done (94% multi-memory
pass rate; remaining tail = D-196). The next-highest-yield §10 row
is **10.E** — currently `[exception-handling] return=34(fail34)
trap=2(fail2) exception=4(fail4)`. The validator side is spec-
correct as of cycle 61; the runtime EH dispatch (throw / catch /
unwind via FP-walk) is the remaining work.

Cycle 77 candidates:

1. **10.E EH runtime — `throw` interp dispatch** — wire the
   `op_throw` handler to construct an Exception object + initiate
   FP-walk unwind. Multi-cycle bundle.
2. **D-178 partial — Linker.defineGlobal** — adds host-side global
   construction surface. Unblocks D-196(a) spectest globals + 2+
   multi-memory fixtures. 1-2 cycles.
3. **Bake 10.TC tail-call return_call fixtures expanded** — tail-call
   spec corpus has 31 returns already; expanding it explores
   ADR-0112 / 10.TC scope. 1 cycle.

Cycle 77 picks (2) — narrow scope (1-2 cycles), clear D-196(a)
discharge, learning that informs Linker.defineGlobal API design
ahead of v0.2 c_api completion (D-178 full discharge).

## Larger §10 work (blocked / later)

- **10.M memory64 multi-memory** — autonomous substantially done
  (37 manifests / 619 passing directives). D-196 tail = D-178
  partial + upstream-corrupted fixtures + named-module register.
- **10.E EH** — validator spec-correct (cycle 61); runtime EH
  dispatch is the next bundle.
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-76; unchanged from 75)

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
- D-178 — Linker.defineGlobal/defineTable missing — cycle-77
  partial-discharge target.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0111 (memory64 + multi-memory design).
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-29-gate-tail-vs-exit-code.md`.
- ROADMAP §10 row 10.M / 10.E; `.dev/phase_log/phase10.md`.
