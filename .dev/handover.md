# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 99 (`ed3a1abd`) — bucket-3 stop documented;
  4 remaining gates inventoried + dependency-ordered.
- Mac aarch64 test-all + lint green; ubuntu x86_64 SSH gate
  confirmed green.
- Session 81→99: D-179 discharged; ADR-0120 + ADR-0123 accepted;
  ValType pivoted to union(enum); GC corpus unlocked (+568
  directives baked).

## Active bundle

- **Bundle-ID**: 10.R-funcrefs-tail (resumed; cycles 100-103 ahead)
- **Cycles-remaining**: ~4
- **Continuity-memo**: cycle 99 dependency-order analysis identified
  3 small structural gaps + 1 larger substrate. Cycles 100/101/102
  ship the small fixes (each ≤ 1 cycle, parser+validator scope);
  cycle 103 closes bundle by re-running spec runner observable +
  filing gate-1 (D-192 cross-module register substrate) as new
  bundle. Per `lessons/2026-05-28-funcrefs-tail-error-classes.md`
  + `lessons/2026-05-28-yield-taper-pacing.md`: chips at validator
  strictness (cycles 96-98) had 0 corpus delta, so cycle 100+
  picks structural sites (parser cases, missing pub-consts) that
  the diagnostic probe explicitly named.
- **Exit-condition**: function-references return pass-rate ≥
  5/39 (currently 0/39) AND ParseFailed count for the corpus < 5
  (currently 10) — i.e. at least half the remaining ParseFailed
  modules clear via cycles 100-102.

## Active task — cycle 100: Gate 4 BadBlockType — accept typed-ref bytes as block result type

Per `lessons/2026-05-28-funcrefs-tail-error-classes.md` (cycle-95
probe): 3 of the 10 ParseFailed function-references modules fire
`BadBlockType`. Block instr's blocktype byte parser (in
`src/validate/validator.zig::readBlockType` + sibling in
`src/ir/lower.zig`) accepts numeric heads + single-byte abstract
refs but rejects `0x63` / `0x64` (typed-ref prefix bytes that
already parse fine as ValType per cycle 92).

Smallest red test (TDD step 2): `test "validator: block (result (ref
null func)) accepts 0x63 0x70 blocktype"` in validator.zig. Add
0x63 / 0x64 arms to `readBlockType` that delegate to
`init_expr.readTypedRef` (or its sibling helper) for the heap-
type byte / SLEB128, returning `BlockType.single = .{ .ref = ... }`.

After cycle 100 lands, cycle 101 = Gate 3 (opRefFunc non-null
push); cycle 102 = Gate 2 (exnref byte 0x69 standalone +
`ValType.exnref` pub-const); cycle 103 = bundle close + open
follow-up bundle for Gate 1 (D-192).

## Larger §10 work (later cycles after bundle close)

- **10.E EH spec corpus (Gate 1 / D-192)** — try_table.1.wasm
  imports `test::e0` tag + `test::throw` func from
  try_table.0.wasm; runner registry needs tag + func cross-
  module binding. ~3-5 cycles. New bundle at 103+ retarget.
- **10.G WasmGC** — corpus baked (568 directives) but impl=0%;
  ZIR ops + heap impl + subtype lattice all still in scope.
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-99)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass) exception=4(fail4)
[function-references] return=39(fail33) trap=4(fail4) invalid=18(pass=18)  ← 3 modules now parse vs cycle-81
[gc                 ] return=407(fail) trap=100(fail) invalid=60(pass) malformed=1(pass)  ← NEW corpus
[multi-memory       ] return=407(pass=371 fail=36) trap=238(pass=237 fail=1)
[wasm-3.0-assert] total: 71 manifests, 2349 directives; assert_invalid pass=193 fail=1
```

## Open questions / blockers

- ADR-0120 / ADR-0123: Accepted; impl autonomous.
- D-179: DISCHARGED (cycle 90).
- D-192: cross-module register substrate. Cycles 103+ open new
  bundle when 10.R-funcrefs-tail closes.
- D-186 (return_call_ref): discharge predicate met by ADR-0123
  D4 + Gate 3 (opRefFunc non-null) once Cycle 5 of original
  bundle closes (which the cycle-103 close finalizes).

## Key refs

- ADR-0120 (Accepted — EH payload), ADR-0123 (Accepted — typed-ref).
- `.dev/lessons/2026-05-28-funcrefs-tail-error-classes.md`
  (cycle 95 diagnostic probe — gate inventory).
- `.dev/lessons/2026-05-28-yield-taper-pacing.md` (3-consecutive
  0-delta cycle detection that triggered the cycle-99 pivot).
- ROADMAP §10; `.dev/phase_log/phase10.md`.
