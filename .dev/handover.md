# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `54945945` — assert_exception execution wired
  (last remaining assertion class). All 5 dispatch paths now
  executing (return / trap / invalid / malformed / exception).
- **ROADMAP §10 progress**: 7/13 DONE (10.0/10.C9/10.J/10.F/
  10.Z/10.D/10.T), 4 IN-PROGRESS (10.M/10.R/10.TC/10.E with
  10.TC trampoline + 10.E spec runner all 5 assertion classes
  wired), 2 Pending (10.G/10.P).
- **Active debt rows**: 18 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows.

## Spec runner full observable (HEAD `54945945`)

```
[memory64           ] return=337 (pass=0  fail=325) trap=205 (pass=0 fail=205) invalid=83 (pass=83 fail=0)  malformed=0 exception=0
[tail-call          ] return=31  (pass=31 fail=0 ) trap=0   (pass=0 fail=0)   invalid=10 (pass=10 fail=0)  malformed=0 exception=0
[exception-handling ] return=34  (pass=0  fail=33) trap=2   (pass=0 fail=2)   invalid=7  (pass=6  fail=1)  malformed=0 exception=4 (pass=0 fail=4)
[gc                 ] (no corpus — D-179 wabt)
[function-references] return=0   (pass=0  fail=0 ) trap=0   (pass=0 fail=0)   invalid=12 (pass=7  fail=5)  malformed=0 exception=0
total: return pass=31 fail=358; trap pass=0 fail=207; invalid pass=106 fail=6; malformed pass=0 fail=0; exception pass=0 fail=4
```

Runner-side dispatch is now complete; remaining gaps are
downstream impl in 10.M (memory64 module-compile fails ~530
directives), 10.E (EH execution doesn't reach UncaughtException
or invoke succeeds for assert_traps), D-188 (6 validator gaps).

## Next sub-chunk candidates (names only)

- **memory64 module-compile gap (10.M scope)** — root-cause
  `wasm_module_new` ParseFailed on memory64 fixtures. Likely
  large multi-cycle bundle; flips ~530 directives. Probably
  warrants bundle-mode designation when picked up.
- **D-188 EH/func-refs validator strictness bisect** — 6 fixtures
  to walk; per-case validator-rule addition.
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
- D-188 — assert_invalid validator gaps (6 cases; EH + func-refs).

## Key refs

- ADR-0017, ADR-0026, ADR-0109 (Native Zig API; recent cycles
  added Instance.exportFuncSig + manifest's runOneTrap /
  runOneExpectException / compileExpectInvalid), ADR-0111,
  ADR-0112, ADR-0113 §A, ADR-0114 D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.T /
  10.TC / 10.E.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
