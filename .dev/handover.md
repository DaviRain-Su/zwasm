# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.M-D195b cycle 71 — spec runner multi-instance
  lifetime + Linker.defineMemory wiring + instantiate-side additive
  memory (imports + defined). `load1.1.wasm` flipped from
  InstantiateFailed to clean; 10 of its 15 asserts now pass.
  Mac aarch64 test-all + lint green.
- **D-188 FULLY DISCHARGED** (cycle 61). **D-194 / D-195(c)**
  DISCHARGED earlier. Active debt rows: 16 — all `blocked-by:`;
  zero `now`.

## Active bundle

- **Bundle-ID**: 10.M-D195b-cross-module-register
- **Cycles-remaining**: ~1
- **Continuity-memo**: D-195 sub-gap (b). Cycles 70-71 done:
  bake-side register emission, parser support, runner multi-instance
  lifetime + Linker.defineMemory + additive memory wiring. Cycle
  72 = invoke routing for `assert_return $M::field`:
  - **Cycle 72**: bake-side emit `$<module>::<field>` for asserts
    whose action carries `module: $X` (see wast2json JSON shape
    `{action: {type: invoke, module: $X, field: read, args: …}}`).
    Manifest parser splits `$X::field` into module_id + func_name.
    Runner maintains a name→inst_idx map (separately from the
    Linker-side defineMemory registry); on `.register <as>` also
    store `cur_inst_idx` keyed by `<as>` and by `$<module-name>`
    (from the `module <name> <path>` directive — bake-side
    enhancement). On invoke with module_id, look up the index +
    use `&instances_list.items[idx]`.
  - **Cycle 72 also**: bake-side `module $<id> <path>` so the
    parser knows the registered name BEFORE the next module
    arrives (load1.wast has both forms: `(module $M …)` then
    `(register "M")` — the JSON's `name: $M` field on the module
    directive needs emission). Without this the registry can't
    map `$M` in asserts to the load1.0 instance.
- **Exit-condition**: `load1` manifest fully green (all 15 returns
  pass, including the 5 `$M::read` asserts).

## Active task — cycle 72: invoke routing for `$module::field`

Smallest red: after cycle 72, load1's 5 `assert_return $M "read"`
directives pass. Currently they fail (mapped to most-recent
instance = load1.1 which has no "read" export → ExportNotFound).

Plan:
1. Bake script: emit `module $<id> <path>` when `c.get('name')` is
   set; emit `assert_return $<id>::<field> …` when
   `c['action'].get('module')` is set (and similarly assert_trap /
   invoke).
2. Manifest parser: extend `module_path` directive to carry an
   optional `module_id`; assert directives carry optional `module_id`
   (parsed from `$<id>::<field>` prefix on the func name token).
3. Runner: maintain `name_to_idx: StringHashMap(usize)` keyed by
   the `$<id>` module name (when present at `.module $<id> <path>`).
   On `.register <as>`, also add `<as>` → cur_inst_idx. On
   assert/invoke with module_id, look up via the map; fall back
   to cur_inst_idx for un-tagged asserts.

## Larger §10 work (blocked / later)

- **10.M multi-memory** — cycle 71 closes a major gap; cycle 72
  closes load1; remaining gaps = data0 corrupted fixtures + non-
  memory cross-imports (out-of-scope for the D-195(b) bundle).
- **10.E EH** — validator side spec-correct (cycle 61); runtime EH
  dispatch + cross-module register (D-192) external-gated.
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-71)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[multi-memory       ] return=330(pass=319 fail=11) trap=220(pass=220 fail=0)  <- +10 (cycle 71)
                      invalid=2(pass=2) malformed=2(pass=2) skip=15
[wasm-3.0-assert    ] assert_return pass=687  assert_trap pass=425  assert_invalid pass=120 fail=0
```

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref +
  return_call_ref impl + typed-ref parser (D-195 sub-gap a).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- D-192 / D-195(b) — runner registry near close (cycle 72).
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0111 (memory64 + multi-memory design).
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-29-gate-tail-vs-exit-code.md`.
- ROADMAP §10 row 10.M; `.dev/phase_log/phase10.md`.
