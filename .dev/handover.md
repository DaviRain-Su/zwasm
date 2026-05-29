# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 143 (finding, no src delta) — instrumented the
  type-subtyping ValidateFailed family with an op-probe: it is
  **RTT-blocked** (`br_on_cast` 0xFB 0x18 ×6 + `br_on_cast_fail`
  0xFB 0x19 ×3 dominate). Ruled out validateTypeSection / concrete
  `subtypeCtx`-chain / ref.eq (lesson `gc-type-subtyping-is-rtt-blocked`).
  gc return still 62. cyc142 (`e0b5b8e3`): array.new_data natural
  element-size (61→62).
- cyc141 array exec + rt.datas production fix (multi-memory +6→393);
  cyc138-140 struct/array const-expr + array.new_data/elem; cyc130-137
  i31/struct/array. gc return 0→…→62, trap 18, multi-memory 393.
- Runner EXECUTES via interp; gc_heap + gc_type_infos + rt.datas all
  materialised at instantiate. Arrays use 8-byte uniform slots
  (type_info.slot_size); data-seg elements are NATURAL width.
- **Bundle 10.E-eh-tail CLOSED** cyc120 (`5db875b0`) — EH corpus FULLY
  GREEN 34/34 (cross-module propagation + caller-frame catch; ADR-0114
  full substrate cyc110–120; D-192 EH clause PROVEN). Lesson
  `eh-cross-module-tag-substrate-scope` has the journey.
- Mac+ubuntu green through cyc142 (`OK (HEAD=a763d44a)`).

## Active bundle

- **Bundle-ID**: 10.G-wasmgc (WasmGC spec corpus — the largest
  remaining §10 gap; follows the CLOSED 10.E EH chain)
- **Cycles-remaining**: ~4 (RTT sub-bundle: ref.test → ref.cast →
  br_on_cast/br_on_cast_fail; extended target ≥90 needs these)
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

## Active task — cycle 144: RTT sub-bundle, chunk 1 = `ref.test` — **NEXT**

cyc143 instrumentation proved the largest remaining gc return family
(type-subtyping ×~10) is RTT (`br_on_cast`). RTT is the extended-target
path. Chunk 1 = **`ref.test` (0xFB 0x14) validate + exec**:
- **Step 0 survey REQUIRED** (new runtime behaviour): RTT type-test in
  GC ref-interp + spec §3.3.5.5 / §4.4.5. Heap-type decode (ht byte →
  abstract any/eq/i31/struct/array/none/func/extern OR concrete $idx).
- **Validate**: pop a ref (subtype-compatible with ht's hierarchy top),
  push i32. **Exec**: pop ref value, test runtime type <: ht against
  `ObjectHeader.info` (concrete $idx → walk supertype chain via the
  per-instance type infos; abstract → kind check; i31ref → low-bit);
  push 1/0. Register handler in `feature/gc/` dispatch like struct/array.
- **Re-derive** the discarded concrete-`subtypeCtx`-chain fix HERE if
  ref.test/cast operand checks need it — it becomes observable in this
  cycle's fixtures (was unobservable solo — see lesson).
Then chunk 2 ref.cast (trap on fail), chunk 3 br_on_cast/_fail (branch).
No regression to 62 return / 18 trap / 57 invalid / 393 multi-mem.

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
[gc                 ] return=407(pass=62 fail=308) trap=100(pass=18 fail=82) invalid=60(pass=57 fail=3) malformed=1(pass) ParseFailed=0 ValidateFailed=33  ← 10.G (cyc142 array.new_data natural-size, return 61→62)
[multi-memory       ] return=407(pass=393 fail=14) trap=238(pass=238) ← cyc141 rt.datas fix (memory.init passive) +6
```

## Open questions / blockers

- D-197: parse/validate/instantiate axis split DONE cyc127
  (ParseFailed/ValidateFailed/InstantiateFailed). Surfacing the
  *specific* validate error (which op/why) is now done ad-hoc via the
  cyc143 op-probe technique (lesson `gc-type-subtyping-is-rtt-blocked`);
  a permanent diag emitter is the remaining D-197 tail (debt row).
- D-192: EH clause PROVEN (EH 34/34). funcrefs clause proven cyc108.

## Key refs

- ADR-0114 (EH `*TagInstance`, IMPLEMENTED cyc110–120); ADR-0115/0116/
  0121 (GC heap + type-info); ADR-0120/0123.
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (full EH journey) + `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
