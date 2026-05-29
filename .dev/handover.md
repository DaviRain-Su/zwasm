# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc146 infra session (`337eb386`) — **ADR-0016 M3**: every
  validate failure now self-attributes (`compile FAIL: <err> — <msg>
  [fn= off= op=]`), retiring the throwaway op-probe (lesson updated).
  Then **concrete→concrete subtypeCtx coercion** (M3 revealed
  type-subtyping.6/7 fail at `call`, not br_on_cast) → **gc
  ValidateFailed 29→27**. **ADR-0125** filed: packed storage types via a
  `StorageType` union (impl queued, atomic refactor).
- cyc145 (`ff45c50d`): br_on_cast/_fail validate (rt2<:rt1, diff types).
  cyc144 (`715468c3`): GC reftype shorthand blocktypes. ValidateFailed
  33→…→27. No regression (gc return 62, trap 18, invalid 57).
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
- **Cycles-remaining**: ~4 (packed StorageType impl [ADR-0125] → then
  RTT exec: ref.test/cast/br_on_cast EXEC type-test → return↑)
- **Continuity-memo**: parse + i31 + struct/array narrowing/exec/const-
  expr all DONE (gc return →62). Substrate landed (don't rebuild):
  `feature/gc/` heap+type_info+i31+collector, struct_ops/array_ops
  registered (api/instance.zig:883-887), ADR-0115/0116/0121/0124/0125.
  **VERIFY by DIRECT binary run**; M3 diagnostic now attributes every
  compile FAIL (`grep "compile FAIL.*op=0x"`) — no throwaway probes.
- **Exit-condition**: gc return ≥ 50 **MET at cyc138 (55)**. Extended
  target: gc return ≥ 90 (array exec + ref.test/cast) — refine as lands.

## Active task — cycle 147: packed storage types (ADR-0125) — **NEXT**

Fully designed in **ADR-0125** (`StorageType` union, atomic refactor —
wants a fresh cycle's full context). M3 attribution confirmed: ref_test.0
/ ref_cast.0 / br_on_cast.0 / struct.0/10 / array.0/7/8 / i31.3 / ref_eq.0
/ extern.0 all fail `type-section decode: BadValType` on i8/i16 fields.
Atomic chunk (one commit — the field rename breaks all readers):
- `sections.zig`: `StorageType{val|packed_}` + `PackedType{i8,i16}`;
  `StructFieldType.valtype`→`storage`; `readFieldType` decodes 0x78/0x77.
- `type_info.zig`: `fieldSlotSize`/`materialiseGcTypes` set
  `valtype_byte=storage.specByte()` + storage width (slot stays 8B).
- `validator.zig`: get/array.get REJECT packed; get_s/_u (sub 3/4, 12/13
  — drop `NotImplemented` at ~1401/1417) push i32 when packed; set/fill
  pop i32 for packed; struct/array subtype cmp (~2807) compares storage.
- exec `struct_ops.zig`/`array_ops.zig`: NEW get_s/_u (extend i8/i16→i32);
  set truncates. ZirOps + lower.zig dispatch already exist.
- ~34 test constructors: `.valtype = X` → `.storage = .{ .val = X }`.

Then **RTT exec** (ref.test/cast/br_on_cast — `ref_test_ops.zig:50-95`
stub + `br_on_cast{,_fail}.zig` NotMigrated; `supertype_chain` zero-filled
at `materialiseGcTypes` ~1016 needs `Types.supertypes` threaded) →
return↑. Use M3 (`grep "compile FAIL.*op=0x"`) to attribute, not probes.
No regression to 62 return / 18 trap / 57 invalid / 393 multi-mem.

## Larger §10 work (later bundles)

- **funcrefs** return 32/39 — 1 externref-elem (runner externref-arg) +
  `resolveFuncrefGlobals` (off spec-corpus path). **10.P close gate** =
  user touchpoint by construction.

## Spec runner observable (cycle-144, DIRECT binary run)

```
[memory64           ] return=337  (all pass)   [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=32/39
[gc                 ] return=62/407 trap=18/100 invalid=57/60 ParseFailed=0 ValidateFailed=31  ← 10.G c144
[multi-memory       ] return=393/407 trap=238/238  ← cyc141 rt.datas fix
```

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
