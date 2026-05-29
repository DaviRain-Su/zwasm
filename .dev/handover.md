# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 119 (`9d5a6212`) — **`*TagInstance` tag identity**
  (ADR-0114 D1): `tag.zig` TagInstance + `Runtime.tags: []*TagInstance`
  (defined = fresh; imported = source instance's pointer, shared) +
  `Exception.tag` stamped by throwOp + catch matches by pointer
  (index fallback → behavior-neutral same-module). Fixed one
  cross-module case: **EH return 31→32/34** (+catchTagMatches unit
  test; no regression). cyc118: block/if param-blocktype fix →31/34.
- **cyc116 (`092e990d`)** — cross-module EH tag import binding
  (ADR-0114, mirror of the FUNC path: `ImportBinding.tag` + Linker
  `defineCrossModuleTag` + `Instance.tag_exports` Option-C side-table +
  runner `.register` binding + `rt.tag_param_counts` imported++defined):
  **EH 0→30/34 return, 0→2/2 trap, 0→4/4 exception**. Detail in the EH
  lesson.
- Prior: 117 probe (tail localized); 115 survey/plan; 114
  imported-tags-in-validator (`5fdab0bf`); 113 catch_ref; 112 exnref.
- Mac test+lint green cyc119. ubuntu: cyc118 HEAD green
  (`OK (HEAD=b392e8fa)`); cyc119 kick backgrounded.

## Active bundle

- **Bundle-ID**: 10.E-eh-tail (the 4 remaining EH return fails +
  execution-identity; follows the CLOSED 10.E-xmodule-tags, exit met
  30/34 @ `092e990d`)
- **Cycles-remaining**: ~1-2
- **Continuity-memo**: **32/34** EH return pass. cyc119 `*TagInstance`
  identity fixed 1 cross-module case (31→32). 2 remaining =
  `catch-imported` + `catch-imported-alias`: need cross-module
  exception **PROPAGATION**. The imported `throw` runs in the source
  instance's runtime (cross_module thunk) → sets
  `source_rt.pending_exception` + returns `Trap.UncaughtException`; the
  thunk propagates the error to the caller's rt, but the catcher
  (`findAndDispatchCatch` in the CALLER's rt) reads
  `caller_rt.pending_exception` = null → the exc (with its correct
  `*TagInstance`, shared) never reaches the caller's catch. Fix:
  transfer the in-flight exc across the cross-module boundary (e.g. the
  thunk moves `source_rt.pending_exception` → caller rt, or the catch
  walk consults the callee's pending exc). `imported-mismatch` (the
  3rd) already passes via `*TagInstance`. **VERIFY by DIRECT binary
  run** (`/tmp/c<NN>` + `/bin/ls -t`; zig-build stderr cache/lossy).
- **Exit-condition**: exception-handling return pass ≥ 33/34 (the 2
  catch-imported cases pass via cross-module exc propagation).

## Active task — cycle 120: cross-module exception propagation

`catch-imported` / `catch-imported-alias` (the last 2 EH return fails):
the exc thrown by an imported func sits in `source_rt.pending_exception`
but the catcher reads `caller_rt.pending_exception` (null) — see
continuity-memo. Survey the cross_module thunk
(`src/runtime/cross_module.zig`) + how `Trap.UncaughtException`
propagates from the callee rt to the caller's interp loop
(`dispatch.zig`/`mvp.zig`). Smallest step: when a cross-module call
returns `Trap.UncaughtException`, move the callee's
`pending_exception` (+ live_exceptions ownership) into the caller rt so
its `findAndDispatchCatch` sees it (the `*TagInstance` already matches,
cyc119). Red = the 2 corpus fails; verify 32→34 by DIRECT binary run.
Then bundle 10.E-eh-tail CLOSES (EH return 34/34) — audit/close.

## Larger §10 work (later bundles)

- **10.G WasmGC** — corpus baked impl=0%; 384 return-fails. D-197
  (surface validate errors) discharges here.
- **Deferred funcrefs gaps** (post-EH): engine/cli_run
  `resolveFuncrefGlobals`; externref-elem runner arg parsing.
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (cycle-119, verified by DIRECT binary run)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(pass=32 fail=2) trap=2(pass) invalid=7(pass) exception=4(pass)
   └─ cyc116 0→30; cyc118 →31; cyc119 *TagInstance →32/34.
      2 fails = cross-module exc PROPAGATION (catch-imported*; cyc120).
[function-references] return=39(pass=32 fail=1) trap=4(pass) invalid=18(pass)
[gc                 ] return=407(fail) trap=100(fail) invalid=60(pass=55 fail=5)
[multi-memory       ] return=407(pass=387 fail=20) trap=238(pass=237 fail=1)
```

## Open questions / blockers

- D-197 (blocked-by 10.G): `Engine.compile`/`frontendValidate` collapse
  specific errors to ParseFailed/bool — surface via Diagnostic.
- D-192: EH cross-module RESOLUTION proven (30/34). Tail = identity.

## Key refs

- ADR-0114 (EH `*TagInstance`); ADR-0120 (EH payload); ADR-0123
  (typed-ref).
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (corrections + the instantiate-binding plan) +
  `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
