# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `b94c9c60` — assert_trap execution wired into
  wasm-3.0-spec runner. Runner now reports
  `trap=N (pass=P fail=F)` per proposal; tail-call has no trap
  directives, memory64/EH show fail-only (downstream module-compile
  gaps, not dispatch path).
- **ROADMAP §10 progress**: 7/13 DONE (10.0/10.C9/10.J/10.F/
  10.Z/10.D/10.T), 4 IN-PROGRESS (10.M/10.R/10.TC/10.E with
  10.E core + 10.TC same-module direct + indirect + interp
  trampoline + 10.E spec runner assert_return + assert_trap
  paths landed), 2 Pending (10.G/10.P).
- **Active debt rows**: 17 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows.

## Active task — 10.E spec runner follow-on

Recent commits this resume:
- `b94c9c60` — assert_trap dispatch (this cycle).
- `21991ffb` chore + `8f8a01ec` feat — 10.TC interp trampoline /
  D-187 discharge (prior cycle). wasm-3.0-assert tail-call
  pass=31 fail=0.
- `c90809f4` chore + `062f3c94` feat — spec runner main-loop
  assert_return wiring (prior session).

Per-proposal observable: `[wasm-3.0-assert] total: 9 manifests,
774 directives; assert_return pass=31 fail=358; assert_trap
pass=0 fail=207`. Trap pass=0 because memory64 + EH modules don't
compile yet (downstream of D-179 + memory64/EH impl gaps); the
runner's trap dispatch path is correct.

## Next sub-chunk candidates (names only)

- **10.E spec runner: assert_invalid execution** — exercise
  validator against `.wasm` paths in manifest's assert_invalid
  directives; mirror assert_trap dispatch shape (any validator
  reject = pass; clean parse = fail).
- **10.E spec runner: assert_malformed execution** — same shape
  as assert_invalid, but for parser-stage reject.
- **memory64 module-compile gap** — root cause `wasm_module_new`
  ParseFailed on `address64.0.wasm` + siblings. Likely missing
  parser arms or validator rules for memory64 features. Would
  flip ~325 assert_return + ~207 assert_trap from fail to pass.
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

## Key refs

- ADR-0017, ADR-0026, ADR-0109 (Native Zig API; adds
  `Instance.exportFuncSig` this cycle), ADR-0111, ADR-0112,
  ADR-0113 §A, ADR-0114 D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.T /
  10.TC / 10.E.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
