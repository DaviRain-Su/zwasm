# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `835cdbb5` — D-188 partial discharge (5/6 cases).
  `frontendValidate` now pre-decodes type/global/table/elem
  section bodies regardless of code-section presence. All 5
  function-references "unknown type" fixtures now correctly
  reject. Only `try_table.10` (EH `catch_all_ref` typing in
  void-result try_table) remains as invalid-accepted.
- **ROADMAP §10 progress**: 7/13 DONE, 4 IN-PROGRESS, 2 Pending.
- **Active debt rows**: 18 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows.

## Spec runner observable (HEAD `835cdbb5`)

```
[memory64           ] return=337 (pass=0  fail=325) trap=205 (pass=0 fail=205) invalid=83 (pass=83  fail=0)  exception=0
[tail-call          ] return=31  (pass=31 fail=0 ) trap=0   (pass=0 fail=0)   invalid=10 (pass=10  fail=0)  exception=0
[exception-handling ] return=34  (pass=0  fail=33) trap=2   (pass=0 fail=2)   invalid=7  (pass=6   fail=1)  exception=4 (pass=0 fail=4)
[gc                 ] (no corpus — D-179 wabt)
[function-references] return=0   (pass=0  fail=0 ) trap=0   (pass=0 fail=0)   invalid=12 (pass=12  fail=0)  exception=0
total: return pass=31 fail=358; trap pass=0 fail=207; invalid pass=111 fail=1; exception pass=0 fail=4
```

Recent commits this resume:
- `835cdbb5` — D-188 partial (5/6 invalid-accepted fixed via
  `preDecodeSectionBodies` in instantiate.zig).
- `a4c04283` chore + `54945945` feat — assert_exception dispatch.
- `63eca92a` chore + `9d6550fd` feat — assert_invalid + malformed
  dispatch.

## Next sub-chunk candidates (names only)

- **memory64 module-compile gap (10.M scope)** — root-cause
  `wasm_module_new` ParseFailed on memory64 fixtures. Largest
  single bottleneck (~530 directives recoverable). Likely
  multi-cycle bundle.
- **D-188 final (try_table.10)** — EH per-clause result-type
  unification for `catch_all_ref` typing. Deeper 10.E validator
  scope.
- **assert_trap class discrimination** — match EXPECTED trap
  reason from wast source (requires re-baking corpus to preserve
  trap messages OR threading through to the runner).
- **10.R-3** — `br_on_non_null` (unblocks 10.R-4 `call_ref` and
  10.R-5 `return_call_ref` per D-186).
- **10.G WasmGC** — large multi-cycle bundle; design plan +
  ADRs (0115/0116/0117) already shipped.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.
- D-186 — `return_call_ref` blocked-by 10.R-3/4/5.
- D-188 — 1 remaining (try_table.10); blocked-by 10.E validator.

## Key refs

- ADR-0017, ADR-0026, ADR-0109 (Native Zig API), ADR-0111,
  ADR-0112, ADR-0113 §A, ADR-0114 D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.T /
  10.TC / 10.E.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
