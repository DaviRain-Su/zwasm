# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `3a6efef2` (cyc204; 10.R-call_ref-JIT IT-2). **JIT `call_ref` executes
  on BOTH arches** — `ref.func $double; call_ref $sig` → 42 via `runI32Export`,
  test UNGATED. arm64 via manual `emit.zig` switch (IT-1); x86_64 via collected
  per-op (`x86_64/ops/wasm_3_0/call_ref.zig` → `emitCallRefCtx`, IT-2) — mirrors
  the `return_call` dispatch shape. emitCallRef = pop funcref (*FuncEntity) →
  null-check → `funcentity_funcptr_offset` deref → CALL (no type-check; validator
  guarantees subtype). Mac test-all + lint GREEN. Only null-trap fixture remains (D-207).
- **10.TC-JIT bundle CLOSED** cyc201: same-module tail-call codegen proven (direct
  0-arg/indirect/recursion-with-args) + real clang `musttail` fixture JIT-checked
  → 15. D-205 discharged; residuals D-206 (cross-module TC + return_call_ref).
- Phase 10 CLOSE-ELIGIBLE (spec corpus interp-complete). Earlier: cyc190-196 gc
  global-init/subtyping + clang_smoke; EH corpus 34/34 (ADR-0114). Runner EXECUTES
  via interp; gc_heap materialised at instantiate. 10.M memory64 + 10.E EH JIT
  largely done; 10.G GC JIT = interp-only (extreme effort, regalloc stack-map).
- **Step 0.7 on resume**: cyc204 (IT-2, code) kicks ubuntu @ `3a6efef2` — verify
  next cycle (x86_64 call_ref now runs the ungated test). Prior: cyc203 (IT-1)
  ubuntu `OK (HEAD=44802a08)` GREEN (call_ref test was aarch64-skipped there).

## Active bundle

- **Bundle-ID**: 10.R-call_ref-JIT
- **Cycles-remaining**: ~1 (null-trap fixture → bundle close; then return_call_ref reuse / D-206)
- **Continuity-memo**: `call_ref` JIT DONE both arches + ungated (arm64 switch IT-1
  `97ca5e0e`; x86_64 collected per-op IT-2 `3a6efef2`). x86_64 verified on ubuntu
  NEXT cycle (Step 0.7). Remaining (D-207): **null-trap fixture** — `ref.null $sig;
  call_ref` → trap. The null-check IS implemented (arm64 `CMP X17,#0; B.EQ`; x86_64
  `OR r,r; JZ` → shared bounds trap stub); just needs a fixture. Blocker: typed
  `ref.null $sig` heap-type binary encoding (concrete type index as heap type) —
  IT-3 Step-0 = confirm the encoding (check an interp tail/funcref fixture or the
  parser's reftype/heaptype decode). Minor follow-up: add `FILE-SIZE-EXEMPT` marker
  to `x86_64/op_call.zig` (now 1020 lines, soft WARN; single-concern call-emit catalog).
- **Exit-condition**: null-trap fixture (`ref.null; call_ref` → trap) green →
  bundle close; then `return_call_ref` reuse (D-206) — it can now mirror
  `emitCallRef` + frame-teardown. (call_ref both arches already met.)

## Active task — 10.R-call_ref-JIT IT-3 (null-trap fixture + close)  **NEXT**

Step-0: confirm the typed `ref.null $sig` binary encoding (`0xd0` + heap-type;
concrete type index encoding) — grep parser reftype/heaptype decode or an existing
interp funcref-null fixture. Then a `runI32Export` (or trap-expecting) test:
exported `test()` does `ref.null $sig; call_ref $sig` → traps (`Error.Trap`). Both
arches (ungated). Then close the 10.R-call_ref-JIT bundle. Also: `FILE-SIZE-EXEMPT`
marker on `x86_64/op_call.zig`. Lighter queued: refresh stale 10.P SKIP rationales
(I14/I21 reference resolved D-192/D-179).

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
