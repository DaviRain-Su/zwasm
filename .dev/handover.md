# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 141 (`81c5e6d3`) — array.new_data/new_elem interp exec
  + **fixed a production rt.datas bug** (instance builder never populated
  rt.datas; only a test helper did → memory.init/array.new_data read
  empty). **multi-memory return 387→393 (+6)** (memory.init passive). No
  regression. gc return 61/trap 18 held (array_new_data.2 compiles but
  value-return still off — decodeData passive parse suspected).
- cyc140 array.new_data/elem validate+lower (trap 10→18); cyc139 array.new
  const-expr (55→61); cyc138 struct.new const-expr (exit ≥50 MET);
  cyc130-137 i31/struct/array narrowing+exec. gc return 0→…→61.
- Runner EXECUTES via interp; gc_heap + gc_type_infos + rt.datas now all
  materialised at instantiate (859-880 / globals ~1262 / data ~1451).
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

## Active task — cycle 142: array_new_data.2 value-return gap — **NEXT**

array.new_data/elem exec + rt.datas landed (cyc141). array_new_data.2
(i32 array from a PASSIVE data seg `aabbccdd` → 3721182122) compiles +
instantiates but its assert_return still fails — value wrong/trap.
INSTRUMENT (cyc131 lesson): run array_new_data.2 via DIRECT binary,
check the runner's got-vs-expected line OR add a probe in arrayNewData.
Leading suspects: (a) decodeData passive-segment parse (flag 0x01)
yields wrong seg.bytes/kind → rt.datas[0] wrong; (b) array element-size
(esz) for i32 ≠ 4 in materialiseGcTypes; (c) array.get reads wrong slot.
Confirm + fix → array_new_data.2 (+ array_new_elem value asserts) pass.
Then remaining gc: packed get_s/u (array_new_data.0/1/3, struct.10), RTT
(ref.test/cast/br_on_cast), type-subtyping linking. No regression to
61 return / 18 trap / 393 multi-mem.

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
[gc                 ] return=407(pass=61 fail=309) trap=100(pass=18 fail=82) invalid=60(pass=57 fail=3) malformed=1(pass) ParseFailed=0 ValidateFailed=33  ← 10.G (cyc141 array exec)
[multi-memory       ] return=407(pass=393 fail=14) trap=238(pass=238) ← cyc141 rt.datas fix (memory.init passive) +6
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
