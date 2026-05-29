# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `92c06c60` (cyc207). **Tail-call JIT matrix COMPLETE both arches** —
  `return_call_ref` now JIT-executes on arm64 + x86_64 (ungated `ref.func;
  return_call_ref` → 42). x86_64 `op_tail_call.emitReturnCallRef` mirrors
  emitIndirectReturnCall tail (frame_teardown + JMP R11) + emitCallRef funcref-deref;
  registered in collected dispatch (count 401). Joins direct/indirect return_call
  (10.TC-JIT) + call_ref (10.R, cyc205). funcref-call JIT (call_ref + return_call_ref)
  done both arches. D-205 discharged; D-206 residual = cross-module TC only;
  D-207 = call_ref/return_call_ref null-trap fixtures. Mac test-all + lint GREEN.
- Earlier: 10.TC same-module tail-call (direct/indirect/recursion + clang musttail
  → 15, cyc198-201); EH corpus 34/34 (ADR-0114); cyc190-196 gc global-init/subtyping.
  Phase 10 CLOSE-ELIGIBLE (spec corpus interp-complete); Runner EXECUTES via interp,
  gc_heap materialised at instantiate. 10.M memory64 + 10.E EH JIT largely done;
  10.G GC JIT = interp-only (extreme: regalloc stack-map, ADR-0113 §C).
- **Step 0.7 on resume**: cyc207 (x86_64 return_call_ref, code) kicks ubuntu @
  `92c06c60` — verify next cycle (return_call_ref test now UNGATED → runs + must
  pass on x86_64). Prior: cyc206 `OK (HEAD=f7303b95)` GREEN.

## Active task — call_ref/return_call_ref null-trap fixtures (D-207)  **NEXT**

Verify the funcref null-check trap path (implemented but untested): a null funcref
through `call_ref`/`return_call_ref` must trap. Step-0: confirm the typed
`ref.null $sig` body-instruction encoding (`0xd0` + heaptype; concrete type index
as s33 → likely `0xd0 0x00` for type 0) — check `init_expr.zig` (handles concrete
heaptype) + the function-body decoder/validator (lower.zig / validator.zig). Then a
`runI32Export` trap-expecting test: exported `test()` does `ref.null $sig; call_ref
$sig` → `Error.Trap` (+ a return_call_ref variant). Both arches (ungated). If the
typed `ref.null` body encoding is unsupported → debt-document + pivot to cross-module
TC survey (D-206). Lighter: refresh stale 10.P SKIP rationales (I14/I21 → D-192/D-179).

## §10 close map

Spec-corpus rows (10.G/10.M/10.E/10.TC/10.R) are mature but ROADMAP-`[ ]`;
formal close needs realworld/p10 + 10.P. Residual:
- **realworld/p10**: clang_musttail DONE (cyc201, JIT result-checked); clang_wasm64
  next-AUTONOMOUS (clang✓); emscripten/dart/ocaml/hoot TOOL-GATED.
- **gc .17** funcref-RTT (D-198 multi-mechanism rabbit hole) — deep defer.
- **funcrefs** 34/39 — 5 gated; **10.P close gate** = user touchpoint.

## Spec runner observable (cyc190, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=349/407 trap=96/100 invalid=60/60 ✅ malformed=1/1 skip=20  ← cyc190 invalid-axis closed
[multi-memory       ] return=407/407 trap=244/244  ← cyc188 ALL-GREEN (D-199/200/201 cross-module chain)
```
> gc residual: return=1 + trap=4 = type-subtyping.30/.48/.50 (the bundle).
> Use `--fail-detail` (reliable per-assert), NOT the per-manifest breakdown.

## Open questions / blockers

- D-197: parse/validate/instantiate split DONE cyc127. Specific
  validate-error surfacing is ad-hoc via the cyc143 op-probe (lesson
  `gc-type-subtyping-is-rtt-blocked`); permanent diag emitter = D-197 tail.
- D-192: EH clause PROVEN (EH 34/34). funcrefs clause proven cyc108.

## Key refs

- ADR-0114 (EH `*TagInstance`, IMPLEMENTED cyc110–120); ADR-0115/0116/
  0121 (GC heap + type-info); ADR-0120/0123.
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (full EH journey) + `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
