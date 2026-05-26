# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `49e6a44a` — D-189 close (memarg natural-alignment
  cap). All 37 wasm-3.0-assert/memory64/align64 invalid-accepted
  cases now reject. Bisect uncovered a single shared root
  cause: validator's `skipMemarg` consumed the align uleb without
  bounds-checking. Fix: `readMemargCheckAlign` + per-op natural-
  alignment dispatch.
- **ROADMAP §10 progress**: 7/13 DONE, 4 IN-PROGRESS, 2 Pending.
- **Active debt rows**: 17 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows.

## Spec runner observable (HEAD `49e6a44a`)

```
[memory64           ] return=337 (pass=51 fail=274) trap=205 (pass=1 fail=204) invalid=83 (pass=83 fail=0)  exception=0
[tail-call          ] return=31  (pass=31 fail=0  ) trap=0   (pass=0 fail=0  ) invalid=10 (pass=10 fail=0) exception=0
[exception-handling ] return=34  (pass=0  fail=33 ) trap=2   (pass=0 fail=2  ) invalid=7  (pass=6  fail=1) exception=4 (pass=0 fail=4)
[gc                 ] (no corpus — D-179 wabt)
[function-references] return=0   (pass=0  fail=0  ) trap=0   (pass=0 fail=0  ) invalid=12 (pass=12 fail=0) exception=0
total: return pass=82 fail=307; trap pass=1 fail=206; invalid pass=111 fail=1; exception pass=0 fail=4
```

assert_invalid now 111/1 — only try_table.10 remains (deep EH
catch_all_ref typing, requires exnref ValType extension).

Recent commits this resume:
- `49e6a44a` — D-189 close (37 align64 cases reject).
- `734348cd` chore + `12f700b5` test — EH compile-gap regression
  marker (10.E pending).
- `da2f16d4` chore + `639c2916` fix — 10.M memory64
  frontendValidate plumbing (+52 directives pass).

## Next sub-chunk candidates (names only)

- **memory64 instantiate gap** — modules compile but
  `linker.instantiate` fails. Likely runtime memory-allocator
  path for i64 memory size. Multi-cycle bundle (10.M runtime
  scope).
- **EH module-compile gap** — `try_table` op validator + interp
  dispatch substrate. The 33+2+4 EH directive fails all root
  here. Multi-cycle (10.E scope).
- **memory64 return/trap fail bisect** — 274 return + 204 trap
  still fail; mix of runtime memory.size/grow with i64 results
  + load/store edge cases. Per-case investigation.
- **D-188 final (try_table.10)** — `catch_all_ref` typing in
  try_table. Requires exnref ValType extension (multi-cycle).
- **10.R-4 / 10.R-5 (call_ref / return_call_ref)** — blocked-by
  D-186 (typed-funcref Value shape ADR).
- **10.G WasmGC** — large multi-cycle bundle.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.
- D-186 — `return_call_ref` blocked-by 10.R-3/4/5.
- D-188 — 1 remaining (try_table.10); blocked-by 10.E validator
  + exnref ValType extension.

## Key refs

- ADR-0017, ADR-0026, ADR-0109, ADR-0111 (memory64 design),
  ADR-0112, ADR-0113 §A, ADR-0114 D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.T /
  10.TC / 10.E / 10.M.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
