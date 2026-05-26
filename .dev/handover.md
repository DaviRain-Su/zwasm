# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `e953b089` — feat(p10): Value.anyref arm +
  Module.needs_gc_heap flag (10.G-foundation cycle 1). Opens the
  10.G WasmGC bundle per ADR-0115/0116. Both additive — no
  semantic consumer yet.
- **ROADMAP §10 progress**: 7/13 DONE, 4 IN-PROGRESS, 2 Pending.
- **Active debt rows**: 18 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows.

## Active bundle

- **Bundle-ID**: 10.G-foundation
- **Cycles-remaining**: ~6 (estimate; foundation substrate before
  full GC heap impl)
- **Continuity-memo**: Cycle 1 (HEAD `e953b089`) lands Value.anyref
  + Module.needs_gc_heap flag (both additive). Next steps: (2)
  parser recognises GC valtype bytes (anyref 0x6E, eqref 0x6D,
  structref 0x6B, arrayref 0x6A, i31ref 0x6C); (3)
  needs_heap_detector.zig walks sections + flips the flag; (4)
  feature/gc/heap.zig per-Store slab (ADR-0115 §1-5); (5)
  Collector vtable + null collector α (ADR-0115 §10); (6)
  regalloc stack-map axis (ADR-0113 §C / ADR-0115 §7).
- **Exit-condition**: needs_gc_heap detector flips true on a wasm
  module declaring `(type $s (struct (field i32)))` AND
  feature/gc/heap.zig allocates the per-Store slab on first GC op.

## Spec runner observable (HEAD `e953b089`)

```
[memory64           ] return=337 (pass=337 fail=0  ) trap=205 (pass=205 fail=0  ) invalid=83  (pass=83  fail=0) skip=0
[tail-call          ] return=31  (pass=31  fail=0  ) trap=0   (pass=0   fail=0  ) invalid=10  (pass=10  fail=0)
[exception-handling ] return=34  (pass=0   fail=34 ) trap=2   (pass=0   fail=2  ) invalid=7   (pass=5   fail=2  ) exception=4 (pass=0 fail=4)
[function-references] invalid=12  (pass=12  fail=0)
total: return pass=368 fail=34; trap pass=205 fail=2; invalid pass=110 fail=2; exception pass=0 fail=4
```

memory64 / tail-call / function-references all clean. Remaining 40
fails all in exception-handling (gate per D-192 / 10.G).

Recent commits this resume:
- `e953b089` feat — Value.anyref + Module.needs_gc_heap (10.G cycle 1).
- `94d16e33` chore — audit_scaffolding §F+§G clean; retarget at 10.G.
- `9b03db83` chore — pivot 10.E-EH-compile-runtime bundle; file D-192.
- `908414b2` fix — frontendValidate threads tags for EH compile.
- `755d33d2` fix — wast baker emits invoke action (D-191 close; memory64 FULL).

## Next sub-chunk candidates (names only)

- **10.G-foundation cycle 2** — parser GC valtype byte recognition
  (anyref 0x6E / eqref 0x6D / structref 0x6B / arrayref 0x6A /
  i31ref 0x6C). Single-cycle: add ValType variants + sections
  decoder branches.
- **10.G-foundation cycle 3** — needs_heap_detector.zig walks
  type / import / global / table / element / function sections
  for GC valtype references; sets Module.needs_gc_heap = true.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- 10.G-4 (struct ops) — blocked-by GC heap impl (10.G bundle scope).
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.
- D-186 — `return_call_ref` blocked-by 10.R-3/4/5 (GC-gated).
- D-188 — 2 now (try_table.8 + try_table.10); blocked-by 10.E
  validator strictness (GC-gated via D-192).
- D-192 — EH runtime path blocked-by exnref ValType + cross-module
  register support (GC-gated).

## Key refs

- ADR-0017, ADR-0026, ADR-0109, ADR-0111 (memory64 design),
  ADR-0112, ADR-0113 §A/§B/§C, ADR-0114, ADR-0115 (GC heap), ADR-0116
  (GC roots + RTT + i31), ADR-0117 (GC×EH×TC integration), ADR-0119,
  ADR-0120.
- ROADMAP §10 row 10.G; Phase log `.dev/phase_log/phase10.md` Row
  10.T / 10.TC / 10.E / 10.M.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
