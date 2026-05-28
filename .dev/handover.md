# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 114 (`5fdab0bf`) — `frontendValidate` now prepends
  IMPORTED tags to the validator tag index space (was defined-only via
  `decodeTags`). try_table.1 imports `test::e0` ×2, so catch/throw
  indices were offset by 2 → `catch-complex-1` StackTypeMismatch (the
  cyc110-113 "ParseFailed" was THIS validate failure, masked per D-197).
  **try_table.1 + try_table.5 now PASS validation** (imp=2 defined=7
  total=9, direct-binary verified). STAGE: validate → **instantiate
  FAIL: UnknownImport** (Linker doesn't bind the imported tag yet).
- Prior: 113 catch_ref/catch_all_ref structural matching (`c968689c`,
  correct but orthogonal); 112 exnref ValType (`64315609`); 111
  stale-cache correction; 110 ImportKind.tag.
- Mac test+lint green cyc114; no spec-corpus regression. ubuntu: cyc113
  HEAD green (`OK (HEAD=1226ff90)`); cyc114 kick backgrounded.

## Active bundle

- **Bundle-ID**: 10.E-xmodule-tags (EH cross-module, ADR-0114)
- **Cycles-remaining**: ~4 (parse+validate done; instantiate-binding
  next, then execution)
- **Continuity-memo**: PARSE (cyc112) + VALIDATE (cyc114) now pass for
  try_table.1/.5. Blocker chain: ~~parse~~ → ~~validate~~ →
  **INSTANTIATE (UnknownImport)** → execution. try_table.1 imports
  `test::e0` (tag) + `test::throw` (func) from try_table.0. The runner's
  `.register` handler binds memory+func exports (cyc110) but NOT tags;
  tag exports were filtered at decode (`sections.zig:606` `kind==4
  continue`); no `ImportBinding.tag` / Linker tag API; instantiate's
  `.tag` import arm returns `ImportTypeMismatch` (stub). Per
  ADR-0114 + the cyc109 lesson plan. **VERIFY by running the runner
  BINARY DIRECTLY** (`/tmp/c<NN>` cache-dir + `/bin/ls -t`; zig-build
  stderr is cache/lossy — D-197 + cache lesson).
- **Exit-condition**: exception-handling try_table corpus return pass
  ≥ 5/34 (currently 0/34).

## Active task — cycle 115: instantiate-side tag binding (UnknownImport)

try_table.1 validates but `instantiate FAIL: UnknownImport` — the
imported `test::e0` tag isn't bound. Step-probe what the c_api
instantiate path needs (the runner uses `Engine.compile` →
`Linker.instantiate`). Likely chain (do the smallest first, verify each
by DIRECT binary run): (1) un-filter tag EXPORTS at decode
(`sections.zig:606`) so try_table.0's `e0` tag export reaches
`exports_storage` + `export_types` (ExportType.tag already exists,
`instance.zig:96`); (2) runner `.register` (`spec_assert_runner_wasm_3_0.zig:357`)
binds tag exports into the Linker; (3) Linker tag-resolution +
`ImportBinding.tag` so instantiate's `.tag` arm resolves instead of
`ImportTypeMismatch`. This is identity-by-index for now; ADR-0114
`*TagInstance` pointer-identity is a LATER step (only needed once
cross-module throw/catch executes). Smallest red: a focused test or the
corpus stage-move (UnknownImport → instantiate OK). Deviation watch:
new `Linker.Payload.tag` / `ImportBinding.tag` variants are §4-adjacent
type additions — routine if mirroring the func/memory binding shape;
file ADR only if the identity model changes.

## Larger §10 work (later bundles)

- **10.E EH execution** (post-validate) — instantiate tag binding +
  `*TagInstance` identity (ADR-0114) + JIT throw/throw_ref emit.
- **10.G WasmGC** — corpus baked impl=0%; 384 return-fails. D-197
  (surface validate errors) discharges here (the 384-fail surface makes
  the plumbing worth it). Many gc/* still ParseFailed (shared ref/GC
  decode).
- **Deferred funcrefs gaps** (post-EH): engine/cli_run
  `resolveFuncrefGlobals`; externref-elem runner arg parsing.
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (cycle-114, verified by DIRECT binary run)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass) exception=4(fail4)
   └─ try_table.0/.2 instantiate; .1/.5 now VALIDATE (cyc114) then
      instantiate FAIL: UnknownImport (imported tag unbound).
[function-references] return=39(pass=32 fail=1) trap=4(pass) invalid=18(pass)
[gc                 ] return=407(fail) trap=100(fail) invalid=60(pass=55 fail=5)
[multi-memory       ] return=407(pass=387 fail=20) trap=238(pass=237 fail=1)
```

## Open questions / blockers

- D-197 (now-ish, blocked-by 10.G): `Engine.compile`/`frontendValidate`
  collapse specific errors to ParseFailed/bool — surface via Diagnostic.
- D-192: EH clause = active bundle 10.E (validator → instantiate → exec).

## Key refs

- ADR-0114 (EH `*TagInstance`); ADR-0120 (EH payload); ADR-0123
  (typed-ref).
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (3 corrections: parse→validator) + `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
