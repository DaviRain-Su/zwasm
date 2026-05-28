# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 106 (`<this commit>`) — SCOPING/PIVOT (no code
  delta). Categorized the 15 function-references return fails: **8 =
  ref_func.1** (its `(import "M" "f")` is UnknownImport because the
  manifest `register` directive is `skip-impl directive-register` —
  D-192 cross-module register substrate, shared with EH try_table);
  ~7 scattered (externref-value arg/result handling in the runner +
  others — to categorize). The funcrefs ENGINE is parse-complete
  (ParseFailed=0) + 24/39 returns pass; the return-rate ≥32 is gated on
  the harness substrate D-192, not engine bugs.
- Prior: 105 element ref.func func-family + ParseFailed→0 (`6e58b534`);
  104 unreachable-poly (`8304714d`); 103 typed table/elem decode
  (`d24ad2da`); 102 ref.func typed (`7b9218c2`); 101 0xD4 (`c82e8124`);
  100 Gate 4 (`2fa216b9`).
- Mac test + lint green (cycle 105/106 — no src change cycle 106).
  ubuntu: cycle-105 HEAD confirmed green (`a0692437`); cycle 106 is
  docs-only (non-code-gap, no kick needed).

## Active bundle

- **Bundle-ID**: 10.X-D192-register (cross-module `register` directive;
  shared by func-refs ref_func.1 + EH try_table)
- **Cycles-remaining**: ~4
- **Continuity-memo**: cycle 106 re-scoped here from 10.R-funcrefs-exec
  (whose ≥32 exit-condition is gated on this substrate). The manifest
  `register` directive is `skip-impl directive-register` at corpus-bake
  time, so a module registered under a name (ref_func.0 as "M",
  try_table.0 providing `test::e0`/`test::throw`) is never available to
  a later module's imports → UnknownImport. D-192 = implement the
  `register` directive: (a) corpus baker emits it (find the skip-impl
  site in `scripts/regen_spec_3_0_assert.sh` / the bake pipeline);
  (b) the runner (`spec_assert_runner_wasm_3_0.zig`) already keeps a
  per-manifest Engine+Linker (cycle 71) — wire `register <name>` to
  `Linker.define*` the registered instance's exports under `<name>` so
  later `instantiate` resolves cross-module imports. **Step 0**: survey
  the bake skip-impl site + the runner's register/Linker path + how EH
  try_table.0→.1 needs the same.
- **Exit-condition**: ref_func.1 instantiates + its 8 assert_returns
  pass (function-references return ≥ 32/39) AND try_table.1 (EH)
  instantiates against try_table.0's registered tag/func.

## Active task — cycle 107: survey + begin the `register` directive substrate (D-192)

**Step 0 (survey)**: (1) where corpus baking emits `skip-impl
directive-register` (grep `scripts/regen_spec_3_0_assert.sh` +
`wast2json` adapter) — the `register` line must be baked into the
manifest instead of skipped; (2) the runner's per-manifest Linker +
how `register <name>` would map the instance's exports into the Linker
namespace for later `instantiate` import resolution; (3) `Linker.define*`
API surface. Then the smallest red step: bake + handle `register` for
ref_func (register ref_func.0 as "M") so ref_func.1 resolves `(import
"M" "f")`. Parallel ~7 scattered funcrefs return fails (externref-value
handling) tracked under the old funcrefs-exec framing — revisit after
D-192 if return < 32.

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

## Spec runner observable (post-cycle-105)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass) exception=4(fail4)
[function-references] return=39(pass=24 fail=15) trap=4(pass=4) invalid=18(pass) ParseFailed=0 (10→7→6→3→1→0)
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
