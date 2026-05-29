# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 139 (`e26276bc`) — array.new const-expr instantiation
  (extended `evalGlobalInitGc` with array.new/new_default/new_fixed,
  mirroring cyc138 struct.new). **gc return 55→61, trap 6→10** —
  array.5/6 (array global inits) instantiate + their ops pass. No
  regression; unit tests green.
- cyc138 struct.new const-expr (return 49→55, bundle exit ≥50 MET);
  cyc136/137 struct/array narrowing; cyc135 GC-type threading; cyc130-133
  i31. gc return: 0→2→18→33→48→49→55→61.
- Runner EXECUTES via interp; gc_heap + inst.gc_type_infos materialised
  at instantiate (instantiate.zig:859-880, before the globals loop ~1262).
- cyc120 (`5db875b0`): cross-module EH propagation + caller-frame catch
  → **EH corpus FULLY GREEN 34/34** (bundle 10.E CLOSED; D-192 PROVEN).
- **Bundle 10.E-eh-tail CLOSED** — exit (return ≥ 33/34) met at 34/34;
  delta cyc119 (`9d5a6212`, *TagInstance: 31→32) + cyc120 (32→34).
  This completes the full EH cross-module substrate (cyc110–120,
  ADR-0114): parser→validator→instantiate-binding→*TagInstance
  identity→cross-module propagation. D-192 EH clause PROVEN.
- Mac green cyc120. ubuntu: cyc120 HEAD green (`OK (HEAD=40d7f0d0)`);
  cyc121-123 docs-only (survey/finding/ADR-0124, no kick).

## Active bundle

- **Bundle-ID**: 10.G-wasmgc (WasmGC spec corpus — the largest
  remaining §10 gap; follows the CLOSED 10.E EH chain)
- **Cycles-remaining**: ~5 (array const-expr → array exec returns →
  ref.test/cast → packed get_s/u → array_copy/data/elem)
- **Continuity-memo**: parse + i31 + struct narrowing/exec all DONE
  (gc return 0→55). Pattern that worked repeatedly: a frontendValidate
  call dropped GC context (elem_count, kinds/struct_defs) → thread it;
  abstract structref/arrayref pushes → make concrete + subtypeCtx
  (concrete→abstract lattice via module_types_kinds); const-expr globals
  → evalGlobalInitStruct (heap alloc). Substrate landed (don't rebuild):
  `feature/gc/` heap+type_info+i31+collector, struct_ops/array_ops
  handlers registered (api/instance.zig:883-887), ADR-0115/0116/0121/0124.
  **VERIFY by DIRECT binary run**; compile FAILs name the axis
  (ParseFailed/ValidateFailed/InstantiateFailed).
- **Exit-condition**: gc return ≥ 50 **MET at cyc138 (55)**. Extended
  target: gc return ≥ 90 (array exec + ref.test/cast) — refine as lands.

## Active task — cycle 140: remaining gc gaps (pick by count) — **NEXT**

struct + array const-expr + i31 all done (return 61). Remaining gc
compile/instantiate failures (from cyc139 DIRECT run), pick the biggest
tractable family — INSTRUMENT first (cyc131 lesson), don't guess:
- **ref.test/ref.cast/br_on_cast** (×~8 ValidateFailed) — RTT typed-ref
  narrowing; validator stubs consume bytes w/o narrowing (ADR-0116 RTT).
- **array_new_data/new_elem** (×8 ValidateFailed) — array init from
  data/elem segments (new validator + exec).
- **type-subtyping.*** (×many) — split: ValidateFailed (subtype edge
  cases) + instantiate SignatureMismatch/UnknownImport (cross-module
  linking of GC types — likely the c_api import-type match).
- **packed struct.get_s/u** (struct.10, array packed) — ADR-0121 D3
  deferred (i8/i16 storage); needs packed ValType.
Localize one family's exact gap → fix. Observable: gc return/validate ↑;
no regression to 61 return / 10 trap / 57 invalid.

## Larger §10 work (later bundles)

- **Deferred funcrefs gaps** (post-EH): funcrefs return 32/39 — 1
  externref-elem (runner externref-arg parsing) + engine/cli_run
  `resolveFuncrefGlobals` (off spec-corpus path).
- **multi-memory** — return 387/407 (20 fails), trap 237/238 (1).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (cycle-120/121, verified by DIRECT binary run)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34/34 trap=2/2 invalid=7/7 exception=4/4  ✅ FULLY GREEN
[function-references] return=39(pass=32 fail=1) trap=4(pass) invalid=18(pass)
[gc                 ] return=407(pass=61 fail=317) trap=100(pass=10 fail=90) invalid=60(pass=57 fail=3) malformed=1(pass) ParseFailed=0 ValidateFailed=38  ← 10.G (cyc139; array.new const-expr, return 55→61, trap 6→10)
[multi-memory       ] return=407(pass=387 fail=20) trap=238(pass=237 fail=1)
```

## Open questions / blockers

- D-197 (now-relevant at 10.G): `Engine.compile`/`frontendValidate`
  collapse specific errors to ParseFailed/bool — surfacing the real
  validate/decode error would make the gc 384-fail debugging precise.
  Discharge candidate this bundle.
- D-192: EH clause PROVEN (EH 34/34). funcrefs clause proven cyc108.

## Key refs

- ADR-0114 (EH `*TagInstance`, IMPLEMENTED cyc110–120); ADR-0115/0116/
  0121 (GC heap + type-info); ADR-0120/0123.
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (full EH journey) + `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
