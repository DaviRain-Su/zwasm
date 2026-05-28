# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 101 (`7db8aed0`) — `ref.as_non_null` opcode typo
  fixed (was dispatched on `0xD3` = GC ref.eq; correct byte is
  `0xD4`) in both validator + lower. cycle 100 (`2fa216b9`) = Gate 4
  BadBlockType (typed-ref blocktype `0x63`/`0x64` accepted).
- Mac aarch64 test + lint green (cycle 101). ubuntu x86_64 SSH gate:
  cycle-100 HEAD confirmed green; cycle-101 kick backgrounded —
  Step 0.7 next resume verifies.
- Session 81→99: D-179 discharged; ADR-0120 + ADR-0123 accepted;
  ValType pivoted to union(enum); GC corpus unlocked (+568
  directives baked).

## Active bundle

- **Bundle-ID**: 10.R-funcrefs-tail (cycles 102-103 ahead)
- **Cycles-remaining**: ~2
- **Continuity-memo**: cycle 100 cleared Gate 4 (ParseFailed 10→7);
  cycle 101 fixed the `ref.as_non_null` 0xD3→0xD4 opcode typo
  (ParseFailed 7→6, `ref_as_non_null.2` parses). **cycle-101 re-probe
  result** (the cycle-99 "Gate 3 = opRefFunc" guess was WRONG): a
  temporary `frontendValidate` per-func error probe mapped the 6
  remaining ParseFailed modules to —
  - `br_on_null.0/2`, `br_on_non_null.0/2` → **StackTypeMismatch**
    (4 modules; func type_idx=0). Highest remaining yield.
  - `ref_as_non_null.0`, `ref_is_null.0` → fail **before** the
    per-function loop (no fv.diag) — earlier frontendValidate stage
    (section decode / preDecode); both use `(elem func N)` +
    `ref.func N` + typed-ref `(ref 0)` params/tables.
- **Exit-condition**: function-references return pass-rate ≥ 5/39
  (currently 0/39) AND corpus ParseFailed < 5 (currently 6) — fixing
  the 4 br_on StackTypeMismatch modules clears the ParseFailed half.

## Active task — cycle 102: br_on_null / br_on_non_null StackTypeMismatch

The 4 highest-yield ParseFailed modules (br_on_null.0/2,
br_on_non_null.0/2) fail validate with StackTypeMismatch (func
type_idx=0). All use the pattern `block; local.get (ref 0);
br_on_null/br_on_non_null 0; call_ref 0; ...` with concrete typed
refs `(ref 0)` / `(ref null 0)` as params. **Step 0**: the error
CLASS is known but not the failing OP — instrument the validator
dispatch loop (print op-byte + pos on error) OR bisect via a focused
`validateFunction` test replicating br_on_null.0 func 0, to pinpoint
which op (likely `call_ref` popExpect, or `br_on_null` label-type
interaction with a concrete `(ref 0)`, or `opRefFunc` typed-ref push
feeding `call`). Then fix the type-equality / subtype path for
concrete typed refs. Smallest red test: that func-0 body via
`validateFunction` (module_types = [()->i32, ((ref 0))->i32]).

After cycle 102: cycle 103 = bundle close (re-run observable; verify
exit-condition) + open follow-up bundle for the pre-loop-failures
(`ref_as_non_null.0` / `ref_is_null.0`) + Gate 1 (D-192). Gate 2
(exnref `0x69`) folds into the D-192/EH bundle.

## Larger §10 work (later cycles after bundle close)

- **10.E EH spec corpus (Gate 1 / D-192)** — try_table.1.wasm
  imports `test::e0` tag + `test::throw` func from try_table.0.wasm;
  runner registry needs tag + func cross-module binding. New bundle
  at 103+ retarget.
- **10.G WasmGC** — corpus baked (568 directives) but impl=0%; ZIR
  ops + heap impl + subtype lattice all still in scope.
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-101)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass) exception=4(fail4)
[function-references] return=39(fail33) trap=4(fail4) invalid=18(pass) ParseFailed=6 (10→7 cyc100, 7→6 cyc101)
[gc                 ] return=407(fail) trap=100(fail) invalid=60(pass=55 fail=5) malformed=1(pass)
[multi-memory       ] return=407(pass=371 fail=36) trap=238(pass=237 fail=1)
```

## Open questions / blockers

- ADR-0120 / ADR-0123: Accepted; impl autonomous.
- D-192: cross-module register substrate. Cycles 103+ open new
  bundle when 10.R-funcrefs-tail closes.
- D-186 (return_call_ref): discharge predicate met by ADR-0123 D4 +
  Gate 3 (opRefFunc non-null) once cycle 101 lands.

## Key refs

- ADR-0120 (Accepted — EH payload), ADR-0123 (Accepted — typed-ref).
- `.dev/lessons/2026-05-28-funcrefs-tail-error-classes.md` (cycle 95
  diagnostic probe — gate inventory; Gate 4 closed cycle 100).
- `.dev/lessons/2026-05-28-yield-taper-pacing.md` (0-delta-cycle
  detection that triggered the cycle-99 pivot).
- ROADMAP §10; `.dev/phase_log/phase10.md`.
