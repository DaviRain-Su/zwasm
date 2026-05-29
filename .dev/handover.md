# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc147 (`3bce968c`) — **ADR-0125 packed storage types**:
  Part A (`ce8a939c`) atomic `StructFieldType.valtype`→`StorageType`
  union rename (behaviour-neutral); Part B-validate decode i8/i16 +
  validator get_s/_u (drop NotImplemented; plain get on packed rejects).
  Packed *decode* was a dominant shared blocker → **gc return 62→105
  (bundle ≥90 EXCEEDED), trap 18→54, ValidateFailed 27→14**, invalid 57
  held, no regression.
- cyc146 infra (`337eb386`): **ADR-0016 M3** validate self-attribution
  (`compile FAIL: … [fn= off= op=]`, retired op-probe) + concrete→concrete
  subtypeCtx coercion (ValidateFailed 29→27). cyc144/145: GC reftype
  blocktypes + br_on_cast/_fail validate.
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
- **Cycles-remaining**: ~3 (packed A+B-validate DONE c147; next =
  B-exec get_s/_u sign-extend → then RTT exec ref.test/cast/br_on_cast)
- **Continuity-memo**: parse + i31 + struct/array narrowing/exec/const-
  expr + packed-validate all DONE (gc return →105). Substrate (don't
  rebuild): `feature/gc/` heap+type_info+i31+collector, struct_ops/
  array_ops registered (api/instance.zig:883-887), StorageType union
  (ADR-0125), ADR-0115/0116/0121/0124. **VERIFY by DIRECT binary run**;
  M3 attributes every compile FAIL (`grep "compile FAIL.*op=0x"`).
- **Exit-condition**: gc return ≥ 90 **EXCEEDED at cyc147 (105)**. Open
  target: maximise return (B-exec + RTT) toward the corpus ceiling.

## Active task — cycle 148: packed get_s/_u EXEC (ADR-0125 B-exec) — **NEXT**

Validate side DONE (c147): packed fields decode + struct.get_s/_u +
array.get_s/_u VALIDATE (push i32). EXEC handlers are still missing →
fixtures that actually READ a packed field fail at exec (in the 247
gc return-fails). Implement:
- `struct_ops.zig` / `array_ops.zig`: NEW interp handlers struct.get_s/_u
  + array.get_s/_u — read the low `FieldInfo` width bytes from the 8-byte
  slot (i8/i16 per `valtype_byte` 0x78/0x77), sign-extend (get_s) /
  zero-extend (get_u) to i32; register in the dispatch table.
- struct.set / array.set / array.fill: truncate i32 → i8/i16 on store to
  a packed field (currently writes the full slot — may need masking).
- ZirOps + lower.zig dispatch already exist; the interp table lacks the
  4 handlers. Use M3 + `grep "compile FAIL.*op=0x"` / direct binary run
  to attribute. Add packed get_s/get_u exec unit tests (sign vs zero).
Then **RTT exec** (ref.test/cast/br_on_cast — `ref_test_ops.zig:50-95`
stub + `br_on_cast{,_fail}.zig` NotMigrated; `supertype_chain` zero-filled
at `materialiseGcTypes` ~1016 needs `Types.supertypes` threaded).
No regression to 105 return / 54 trap / 57 invalid / 393 multi-mem.

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
