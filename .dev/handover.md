# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 118 (`fd29cbda`) — `block`/`if` param-blocktype fix:
  `mvp.zig` blockOp/ifOp used the packed `(params<<8)|results`
  (lower.zig readBlockArity) as the whole label arity → `try_table
  (param i32)` set arity=0x100 > max_block_arity → trap. Now low byte =
  arity, height excludes params. **EH return 30→31/34** (try-with-param
  fixed); +interp unit test; no regression. (cyc117 was probe-only.)
- **cyc116 (`092e990d`)** — cross-module EH tag import binding
  (ADR-0114, mirror of the FUNC path: `ImportBinding.tag` + Linker
  `defineCrossModuleTag` + `Instance.tag_exports` Option-C side-table +
  runner `.register` binding + `rt.tag_param_counts` imported++defined):
  **EH 0→30/34 return, 0→2/2 trap, 0→4/4 exception**. Detail in the EH
  lesson.
- Prior: 117 probe (tail localized); 115 survey/plan; 114
  imported-tags-in-validator (`5fdab0bf`); 113 catch_ref; 112 exnref.
- Mac test+lint green cyc118. ubuntu: cyc116 HEAD green
  (`OK (HEAD=4512fefa)`); cyc117 docs-only; cyc118 kick backgrounded.

## Active bundle

- **Bundle-ID**: 10.E-eh-tail (the 4 remaining EH return fails +
  execution-identity; follows the CLOSED 10.E-xmodule-tags, exit met
  30/34 @ `092e990d`)
- **Cycles-remaining**: ~2-3
- **Continuity-memo**: **31/34** EH return pass (cyc118 fixed
  try-with-param). 3 remaining fails = **cross-module tag identity**:
  `catch-imported` + `catch-imported-alias` + `imported-mismatch`. The
  imported `throw` func runs in try_table.0's runtime (its tag index);
  try_table.1's catch compares its own import index → index-based
  mismatch across modules → uncaught → InvokeFailed. Fix = ADR-0114
  `*TagInstance` pointer identity — multi-cycle: create `tag.zig`
  TagInstance + `rt.tags: []*TagInstance` (populate defined = fresh,
  imported = copy the binding's source `*TagInstance`) + `Exception.tag`
  → `*TagInstance` + throw/catch match by pointer across the
  cross-module thunk. `ImportBinding.tag` currently carries
  (source_runtime, source_tag_index) — enough to derive the shared
  `*TagInstance`. **VERIFY by DIRECT binary run** (`/tmp/c<NN>` +
  `/bin/ls -t`; zig-build stderr is cache/lossy — D-197 + cache lesson).
- **Exit-condition**: exception-handling return pass ≥ 33/34 (the 3
  cross-module cases pass via `*TagInstance`) OR root-caused + next.

## Active task — cycle 119: `*TagInstance` cross-module identity (ADR-0114)

The 3 remaining EH fails are cross-module tag identity (see
continuity-memo). Multi-cycle substrate per ADR-0114 + the cyc115 EH
lesson plan. Smallest first observable step: create `tag.zig`
`TagInstance` (heap object; address = identity) + `Runtime.tags:
[]*TagInstance`, populate at instantiate (defined tags → fresh
TagInstance at slot imp_count+i; imported → copy the
`ImportBinding.tag` source's `*TagInstance`). Unit test: rt.tags
populated with distinct pointers. THEN (next cycle) thread
`Exception.tag` → `*TagInstance` + throw/catch match by pointer (the
interp throw/catch + the cross-module thunk's exception propagation) →
the 3 fails pass. Deviation watch: `Runtime.tags` + `Exception.tag`
shape are §4-adjacent but implement Accepted ADR-0114 (no new ADR);
file only if the identity model itself changes. **VERIFY by DIRECT
binary run** (EH return 31→34).

## Larger §10 work (later bundles)

- **10.G WasmGC** — corpus baked impl=0%; 384 return-fails. D-197
  (surface validate errors) discharges here.
- **Deferred funcrefs gaps** (post-EH): engine/cli_run
  `resolveFuncrefGlobals`; externref-elem runner arg parsing.
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (cycle-118, verified by DIRECT binary run)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(pass=31 fail=3) trap=2(pass) invalid=7(pass) exception=4(pass)
   └─ cyc116 tag binding 0→30/34; cyc118 try-with-param →31/34.
      3 fails = cross-module *TagInstance identity (cyc119+).
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
