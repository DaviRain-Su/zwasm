# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `93270e98` (cyc205). **10.R-call_ref-JIT bundle CLOSED** — JIT `call_ref`
  executes on BOTH arches, verified on ubuntu @ `5f104ff4` (`ref.func $double;
  call_ref $sig` → 42, ungated test green both hosts). arm64 via manual `emit.zig`
  switch (IT-1 `97ca5e0e`); x86_64 via collected per-op (IT-2 `3a6efef2`) — mirrors
  the `return_call` dispatch shape. emitCallRef = pop funcref (*FuncEntity) →
  null-check → `funcentity_funcptr_offset` deref → CALL. cyc205 added the
  `x86_64/op_call.zig` FILE-SIZE-EXEMPT marker. Residual: null-trap fixture (D-207).
- **10.TC-JIT bundle CLOSED** cyc201: same-module tail-call codegen proven (direct
  0-arg/indirect/recursion-with-args) + real clang `musttail` fixture JIT-checked
  → 15. D-205 discharged; residuals D-206 (cross-module TC + return_call_ref).
- Phase 10 CLOSE-ELIGIBLE (spec corpus interp-complete). Earlier: cyc190-196 gc
  global-init/subtyping + clang_smoke; EH corpus 34/34 (ADR-0114). Runner EXECUTES
  via interp; gc_heap materialised at instantiate. 10.M memory64 + 10.E EH JIT
  largely done; 10.G GC JIT = interp-only (extreme effort, regalloc stack-map).
- **Step 0.7 on resume**: cyc205 (EXEMPT marker, behaviour-neutral src) kicks ubuntu
  @ `93270e98` — verify next cycle. Prior: cyc204 (IT-2) ubuntu `OK (HEAD=5f104ff4)`
  GREEN — **x86_64 call_ref confirmed** (the ungated test ran on x86_64 + passed).

## Active task — return_call_ref JIT (D-206 / D-186)  **NEXT**

`call_ref` JIT done (bundle closed) UNBLOCKS `return_call_ref` — its
`ops/wasm_3_0/return_call_ref.zig` is a one-line `UnsupportedOp` stub. It's the
tail-call variant of call_ref: pop funcref (*FuncEntity) → null-check → load
`funcentity_funcptr_offset` → frame_teardown → BR/JMP (tail). Reuses the
just-built `emitCallRef` funcref-deref + the tail-call `frame_teardown` (10.TC-JIT
bundle). liveness: `return_call_ref` is ALREADY classified as a terminator (cyc198
fix included it). Step-0: read `op_tail_call.emitIndirectReturnCall` (the BR-after-
teardown shape) + `emitCallRef` (funcref deref); red test = `ref.func $f;
return_call_ref $sig` tail-call → result. arm64 first (manual switch like
return_call), then x86_64 (collected per-op). Smaller follow-ups: null-trap fixture
for call_ref (D-207); refresh stale 10.P SKIP rationales (I14/I21 → D-192/D-179).

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
