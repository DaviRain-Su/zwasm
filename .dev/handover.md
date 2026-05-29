# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 145 (`ff45c50d`) — spec-correct **br_on_cast /
  br_on_cast_fail validate** (§3.3.5.5): decode ht1/ht2, enforce
  `rt2 <: rt1` (full reftype incl. nullability), cast/cast_fail label-
  carry + fall-through difference types, subtype label match (was the
  cycle-9 `eql(operand)` stub). **gc ValidateFailed 31→29**; invalid
  stays 57 (6 assert_invalid still rejected); 3 unit tests; no regression.
- cyc144 (`715468c3`): GC reftype shorthand blocktypes (ValidateFailed
  33→31). cyc143: type-subtyping family is RTT-blocked (lesson).
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
- **Cycles-remaining**: ~3 (RTT: blocktype c144 + br_on_cast validate
  c145 DONE; next = ref.test/cast/br_on_cast EXEC type-test → return↑)
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

## Active task — cycle 146: ref.test/cast/br_on_cast EXEC type-test — **NEXT**

br_on_cast/br_on_cast_fail now VALIDATE; modules compile but fail exec
(NotMigrated) → no return delta yet. EXEC is the `return≥90` path.
- **ref.test EXEC** (`ref_test_ops.zig:50-95` is a cycle-7 stub: returns
  1 if non-null, ignores the heap_type in `instr.payload`). Decode the
  ht, dispatch: abstract (i31 via Value low-bit / struct,array via
  `ObjectHeader.kind` / any,eq non-null) → kind check; concrete $idx →
  supertype chain. Then ref.cast (trap on mismatch), br_on_cast/_fail
  (`br_on_cast{,_fail}.zig` return NotMigrated — wire the branch).
  Registration: `api/instance.zig:881-888`.
- **Concrete-type gap**: `TypeInfo.supertype_chain` zero-filled at
  `instantiate.zig materialiseGcTypes` (~1016, comment 65-68). Thread
  the parser's `Types.supertypes` before concrete-$idx tests work.
- **Separate (smaller) blocker**: ref_test.0/ref_cast.0 fail validate
  EARLIER (before func loop) on bottom-type heap shorthands `none`
  (0x71) / `nofunc` (0x73) / `noextern` (0x72) — `init_expr.readValType`
  lacks standalone arms for them (only 0x70..0x69). Add + sibling-check.
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
