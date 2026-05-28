# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 108 (`e3a22ec2`) — `ref.func` in a global init expr
  now resolves at instantiate (evalConstExprValue had no 0xD2 arm; the
  global-init loop resolves against rt.func_entities). With cycle-107's
  `register M`, **ref_func.1 instantiates + runs its 8 asserts**:
  function-references **return pass 24 → 32**. D-192 funcrefs clause MET.
- Prior: 107 register M baked (`590578e1`); 106 scoping/pivot
  (`e0766509`); 105 element ref.func func-family + ParseFailed→0
  (`6e58b534`); 104 unreachable-poly (`8304714d`); 100-103 funcrefs
  parse chain.
- Mac test + lint green (cycle 108). ubuntu: cycle-107 HEAD green
  (`bb426c07`); cycle-108 kick backgrounded.

## Active bundle

- **Bundle-ID**: 10.X-D192-register (cross-module `register` directive;
  shared by func-refs ref_func.1 + EH try_table)
- **Cycles-remaining**: ~3
- **Continuity-memo**: D-192 funcrefs clause DONE (register M cyc107 +
  ref.func global-init cyc108 → return 24→32). Remaining work:
  1. **EH try_table.1 register** (the other D-192 clause) — try_table.1
     imports `test::e0` tag + `test::throw` func from try_table.0. Check
     if the EH manifest has a stale `skip-impl directive-register` (like
     ref_func did) + whether the runner binds cross-module TAG exports
     (defineCrossModuleFunc covers funcs; tags may need a new binding).
  2. **Engine-path ref.func-global gap** (cli_run, NOT spec corpus):
     `resolveFuncrefGlobals` (compile_init.zig) is defined but NEVER
     called → cli_run funcref globals with ref.func init read null; AND
     validateGlobalInitExpr (runner_validate.zig:113) produces abstract
     funcref for ref.func (cycle-102-class), mismatching a typed
     `(ref $t)` global. Real cli_run bug; separate subsystem from the
     c_api fix (which the spec corpus guards).
  3. **externref-elem** (1 fail) — runner can't parse externref invoke
     args, so the `init` side-effect is skipped → table 1 stays empty.
- **Exit-condition**: try_table.1 (EH) instantiates against
  try_table.0's registered tag/func (the remaining D-192 clause; the
  funcrefs ≥32 clause is MET).

## Active task — cycle 109: EH try_table.1 cross-module register (D-192 EH clause)

Apply the now-proven register substrate to EH. **Step 0**: (1) does the
exception-handling try_table manifest carry a stale `skip-impl
directive-register` (re-bake like ref_func if so)? (2) try_table.1
imports a TAG (`test::e0`) + func (`test::throw`) from try_table.0 —
the runner's `.register` handler binds func exports
(defineCrossModuleFunc) but TAG exports are in the
`.table, .global => {out of scope}` arm (line ~396); EH needs a
cross-module TAG binding. Probe try_table.1's instantiate error first
(UnknownImport on the tag vs func), then wire the tag binding. Parallel:
the engine-path ref.func-global gap (item 2) is a clean cli_run fix
(wire resolveFuncrefGlobals + typed-global ref.func) if EH stalls.

## Larger §10 work (later bundles)

- **10.E EH spec corpus (Gate 1 / D-192)** — try_table.1.wasm imports
  `test::e0` tag + `test::throw` func from try_table.0.wasm; runner
  registry needs tag + func cross-module binding. Gate 2 (exnref byte
  `0x69` standalone + `ValType.exnref` pub-const) folds in here.
- **10.G WasmGC** — corpus baked (568 directives) but impl=0%; ZIR ops
  + heap impl + subtype lattice. NOTE: `valTypeIsSubtypeFree`'s
  `(ref $concrete) <: func` rule assumes pre-GC (all concrete = func
  type); 10.G must refine once struct/array heads enter module_types.
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-108)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass) exception=4(fail4)
[function-references] return=39(pass=32 fail=1) trap=4(pass=4) invalid=18(pass) ParseFailed=0  (return 0→7→12→24→32 cyc100-108; only externref-elem left)
[gc                 ] return=407(fail) trap=100(fail) invalid=60(pass=55 fail=5) malformed=1(pass)
[multi-memory       ] return=407(pass=371 fail=36) trap=238(pass=237 fail=1)
```

## Open questions / blockers

- ADR-0120 / ADR-0123: Accepted; impl autonomous. ADR-0123 D4
  (ref.func typed) landed cycle 102.
- D-192: cross-module register substrate. New bundle after
  10.R-funcrefs-tail-2 closes.
- D-186 (return_call_ref): discharge predicate met by ADR-0123 D4 +
  cycle-102 opRefFunc typed push.

## Key refs

- ADR-0120 (Accepted — EH payload), ADR-0123 (Accepted — typed-ref;
  D4 ref.func typed landed cycle 102).
- `.dev/lessons/2026-05-28-funcrefs-tail-error-classes.md` (gate
  inventory + cycle-101/102 re-probe maps).
- ROADMAP §10; `.dev/phase_log/phase10.md`.
