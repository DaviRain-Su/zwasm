# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `81eeb6fa` (cyc202; 10.TC-JIT IT-5 + bundle-close @ `5457997c`/`81eeb6fa`).
  cyc202 surveyed the JIT halves → next = **10.R `call_ref` JIT** (see Active bundle). **10.TC-JIT bundle CLOSED** — JIT
  tail-call codegen done + proven: direct 0-arg (IT-2), indirect table[0] (IT-3),
  recursion-WITH-ARGS (IT-4), and a **real clang `__attribute__((musttail))`
  fixture JIT-result-checked → 15** (IT-5). Root fix was the liveness
  terminator-class (`src/ir/analysis/liveness.zig`, ADR-0113 §A, IT-2); emit was
  already wired. New realworld-p10 JIT result-check harness (`build.zig`
  `run_edge_realworld_p10`, in test-all). Mac test-all GREEN; ubuntu GREEN
  through IT-4. **D-205 clang_musttail concern discharged**; 10.TC residuals
  (cross-module TC, return_call_ref) → debt. Phase 10 CLOSE-ELIGIBLE (spec corpus
  interp-complete); path (b) continuing the §10 JIT halves.
- cyc196 (`086c2991`) first clang-realworld fixture (clang_smoke; pipeline proven).
  Realworld-clang findings: JIT can't run `return_call` (D-205); runI32Export
  doesn't instantiate; → non-trivial clang fixtures need harness work.
- cyc195 non-null-local definite-assignment → **test-all GREEN** (gate restored,
  bundle 10.Y closed). cyc194 restored wast-runner compile. cyc190-193: gc
  global-init / import subtyping / assert_unlinkable. gc residual: .17 (D-198)
  + 5 unlinkable (D-202). All Mac+ubuntu green through cyc195.
- Earlier arc: cyc177 iso-recursive canonicalEqual; cyc147-148 ADR-0125
  packed; cyc146 ADR-0016 M3 self-attribution; cyc130-140 i31/struct/array.
- Runner EXECUTES via interp; gc_heap + gc_type_infos + rt.datas all
  materialised at instantiate. Arrays use 8-byte uniform slots
  (type_info.slot_size); data-seg elements are NATURAL width.
- EH corpus FULLY GREEN 34/34 (ADR-0114 substrate cyc110-120; lesson
  `eh-cross-module-tag-substrate-scope` has the journey).
- **Step 0.7 on resume**: last ubuntu kick = cyc201 (IT-5) `OK (HEAD=81eeb6fa)` GREEN
  (spec 212/0, simd 13351/0, realworld 46/55 compile-pass). cyc202 is a survey +
  handover-only docs cycle (no code) → no ubuntu kick; green holds.

## Active bundle

- **Bundle-ID**: 10.R-call_ref-JIT
- **Cycles-remaining**: ~2-3 (arm64 call_ref emit + liveness + test → x86_64 → then return_call_ref reuse)
- **Continuity-memo**: JIT-halves survey (cyc202, `private/notes/p10-jit-halves-survey.md`)
  picked `call_ref` JIT as highest value: unblocks ~25 function-references spec
  fixtures (D-186) + `return_call_ref`/D-206, reuses `call_indirect` machinery,
  no new regalloc axes. **Funcref representation**: `ref.func idx` (already
  JIT-emitted, `emit.zig:807`) pushes `@intFromPtr(&rt.func_entities[idx])` — a
  `*FuncEntity` (Value.fromFuncRef encoding, ADR-0014 §2.1). `call_ref $sig` plan:
  pop funcref vreg → null-check (CBZ → trap) → marshal args (`op_call.marshalCallArgs`)
  → load JIT-entry from the FuncEntity (Step-0: confirm `FuncEntity` layout +
  jit-entry/funcptr field offset in `jit_abi` / runtime) → MOV X0,X19 → BLR →
  `op_call.captureCallResult`. NO runtime type-check (validator guarantees the
  funcref's type ⊑ `$sig`). Touches: (1) `liveness.zig` — add `call_ref` arm
  (pop funcref + sig.params, push sig.results; sig from `module_types[payload]`;
  NON-terminator, mirror the `.call`/`.call_indirect` block ~line 438, NOT the
  tail-call terminator branch); (2) new `arm64/ops/wasm_3_0/call_ref.zig` +
  `op_call_ref` emit; (3) dispatch wiring (`emit.zig` + `dispatch_collector`);
  (4) x86_64 mirror; (5) runI32Export red test.
- **Exit-condition**: `ref.func $double; call_ref $sig` JIT-executes → 42 via
  `runI32Export` (arm64 first); test-all GREEN, 0 panics. Then x86_64 + a
  funcref-corpus delta.

## Active task — 10.R-call_ref-JIT IT-1  **NEXT**

Step-0: confirm `FuncEntity` struct layout (jit-entry/compiled-funcptr field +
offset) in `src/engine/.../jit_abi*` + the runtime `FuncEntity` def, and how
`call_indirect` resolves a funcptr (`op_call.emitCallIndirect`) to mirror. Then
red test: module with `$double (param i32)(result i32)` + exported `test()` doing
`i32.const 21; ref.func $double; call_ref $sig` → 42. Add the `call_ref` liveness
arm + arm64 `op_call_ref` emit + dispatch wiring → green. Lighter queued: refresh
stale 10.P SKIP rationales (I14/I21 reference resolved D-192/D-179).

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
