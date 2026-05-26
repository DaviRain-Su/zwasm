# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `639c2916` — memory64 frontendValidate fix (10.M
  progress). `memory0_idx_type` now threaded into validator;
  memory64 modules with i64 addresses no longer reject as
  StackTypeMismatch. +52 directives pass (51 assert_return + 1
  assert_trap); surfaced 37 invalid-accepted memory64 cases →
  D-189 (per-case 10.M validator gaps).
- **ROADMAP §10 progress**: 7/13 DONE, 4 IN-PROGRESS, 2 Pending.
- **Active debt rows**: 19 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows.

## Spec runner observable (HEAD `639c2916`)

```
[memory64           ] return=337 (pass=51 fail=274) trap=205 (pass=1 fail=204) invalid=83 (pass=46 fail=37) exception=0
[tail-call          ] return=31  (pass=31 fail=0  ) trap=0   (pass=0 fail=0  ) invalid=10 (pass=10 fail=0 ) exception=0
[exception-handling ] return=34  (pass=0  fail=33 ) trap=2   (pass=0 fail=2  ) invalid=7  (pass=6  fail=1 ) exception=4 (pass=0 fail=4)
[gc                 ] (no corpus — D-179 wabt)
[function-references] return=0   (pass=0  fail=0  ) trap=0   (pass=0 fail=0  ) invalid=12 (pass=12 fail=0 ) exception=0
total: return pass=82 fail=307; trap pass=1 fail=206; invalid pass=74 fail=38; exception pass=0 fail=4
```

Recent commits this resume:
- `639c2916` — memory64 frontendValidate plumbing (10.M progress).
- `d9bea3b7` chore + `835cdbb5` fix — D-188 partial (5/6 invalid-
  accepted discharged via preDecodeSectionBodies).

## Next sub-chunk candidates (names only)

- **D-189 memory64 invalid-accepted bisect** — identify 37
  fixtures + their spec rules; add validator arms per case.
  Bounded by 10.M scope.
- **memory64 trap fail bisect** — 204 memory64 assert_trap fail;
  many likely OOB-load runtime trap cases. Investigate how
  current runtime handles i64 addressing in load/store; if
  runtime correctly raises OOB-bounds for i64 addresses ≥ mem.size,
  these should flip pass.
- **memory64 return fail bisect** — 274 still fail; mix of
  runtime memory.size/grow with i64 results + load/store edge
  cases. Per-case investigation.
- **D-188 final (try_table.10)** — EH per-clause result-type
  unification for `catch_all_ref` typing.
- **10.R-3** — `br_on_non_null` (unblocks 10.R-4 / 10.R-5).
- **10.G WasmGC** — large multi-cycle bundle.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.
- D-186 — `return_call_ref` blocked-by 10.R-3/4/5.
- D-188 — 1 remaining (try_table.10); blocked-by 10.E validator.
- D-189 — 37 memory64 invalid-accepted (10.M validator gaps).

## Key refs

- ADR-0017, ADR-0026, ADR-0109, ADR-0111 (memory64 design —
  D1 memory0_idx_type field is the contract this cycle plumbed),
  ADR-0112, ADR-0113 §A, ADR-0114 D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.T /
  10.TC / 10.E / 10.M.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
