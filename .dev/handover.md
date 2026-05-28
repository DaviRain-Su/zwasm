# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 90 — **3 ADR/debt gates closed in one pass**:
  - **D-179 discharged** (Track A `6e5e7e53`): baker swap wabt →
    wasm-tools; GC corpus unlocked, +568 spec runner directives.
  - **ADR-0120 revised + Accepted + Cycle 1 impl** (Track B
    `510eca36`): `eh_payload []u64` pre-sized at instantiate (no
    magic cap); D5 v128 slot accounting; D6 catch_ref lazy
    reification.
  - **ADR-0123 revised + Accepted + Cycle 1 impl** (Track C
    `d6b187f8`): RefType / HeapType / AbstractHeapType substrate
    added. Bundle 10.R-valtype-widen opens.
- Mac aarch64 test-all + lint green.

## Active bundle

- **Bundle-ID**: 10.R-valtype-widen
- **Cycles-remaining**: ~4-5
- **Continuity-memo**: Substrate types (RefType / HeapType /
  AbstractHeapType) added at cycle 90 Cycle 1. Cycle 2 pivots
  `ValType` from `enum(u8)` to `union(enum)` with `ref: RefType`
  variant; migrate 7 abstract-ref enum tags (funcref / externref /
  i31ref / anyref / eqref / structref / arrayref) to
  `.ref = RefType.abs(.X, true)`. Zig `require_exhaustive_enum_switch`
  lint guides every site.
- **Exit-condition**: function-references spec corpus assert_return
  pass-rate ≥ 30/39 (currently 3/39); call_ref + return_call_ref
  green-baked + validated; 0 ParseFailed for any
  function-references module.

## Active task — cycle 91: ValType pivot (Cycle 2 of bundle)

Smallest red test:
`test "ValType: union(enum) — .ref = RefType.abs(.func, true) equals legacy funcref representation"`
in `src/ir/zir.zig`. Existing 7 abstract-ref enum tags get an
`.absRef(...)` constructor + comptime-assert preservation of byte
mapping (funcref = 0x70, externref = 0x6F, etc.) per Wasm 3.0 §5.3.1.

After cycle 2 lands, cycles 3-5 per ADR-0123 Consequences §5:
- Cycle 3: parser `0x63` / `0x64` for `(ref null? ht)`.
- Cycle 4: validator static narrowing rules.
- Cycle 5: call_ref / return_call_ref impl (D3/D4) + spec corpus
  pass-rate ramp.

## Larger §10 work (post-bundle)

- **10.E EH payload-prop bundle** (ADR-0120 Cycles 2-5): throw.emit
  pop+STR; try_table.emit catch landing-pad LDR+push; catch_ref
  reification helper; spec corpus runner wiring. ~30 EH directives
  flip to pass.
- **10.G WasmGC ZIR ops** — D-179 unblocked at the bake layer;
  impl distance is large (ZIR op set + heap impl + subtype lattice
  reuse ADR-0123 RefType shape).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-90 baker swap)

```
[memory64           ] return=337(all pass) trap=205(all pass) invalid=83
[tail-call          ] return=71  trap=7    invalid=24(pass=23 fail=1)
[exception-handling ] return=34(fail) trap=2(fail) invalid=7(pass) exception=4(fail)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[gc                 ] return=407(fail=384) trap=100(fail=100) invalid=60(pass) malformed=1(pass)  ← NEW
[multi-memory       ] return=407(pass=371 fail=36) trap=238(pass=237 fail=1) invalid=2 malformed=2 skip=56
[wasm-3.0-assert] total: 71 manifests, 2349 directives
```

## Open questions / blockers

- ADR-0120 / ADR-0123 — both Accepted; impl bundles autonomous.
- D-179 — DISCHARGED.
- D-186 — discharge path unblocked by ADR-0123 D4; awaits cycle 5
  of 10.R-valtype-widen bundle.
- D-195 (function-references corpus gates) — sub-gap (a) unblocked
  by ADR-0123 Cycle 3; sub-gap (b) cross-module register remains.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0120 (Accepted — EH payload), ADR-0123 (Accepted — typed-ref).
- `.dev/lessons/2026-05-28-spec-corpus-expansion-exhausted.md`
  (cycle-88 survey that surfaced these gates).
- ROADMAP §10; `.dev/phase_log/phase10.md`.
