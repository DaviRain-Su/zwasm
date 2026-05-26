# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `9b03db83` — chore(p10): pivot 10.E-EH-compile-runtime
  bundle; file D-192. Cycle-1 slice of 10.E (compile path) closed
  at `908414b2`; deeper EH runtime path blocked-by exnref ValType +
  cross-module register (D-192).
- **ROADMAP §10 progress**: 7/13 DONE, 4 IN-PROGRESS, 2 Pending.
- **Active debt rows**: 18 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows.

## Audit-scaffolding (narrow §F + §G; this cycle)

- §F.5 skip-ADRs: 0 violations.
- §F.6 ADR history: 8 `<backfill>` placeholders pending (soon —
  batch backfill at Phase 10 close per F.7).
- §F.3a lesson citing: OK.
- §F.10 dual-view table sync: 0 violations.
- §G.1.1 skip taxonomy: OK.
- §G.1.2 ADR-0078 pairing: 0 block findings.
- §G.3 comment-as-invariant: 0 latent overlap sites.
- §G.4 spike lifecycle: 3 stale merged-into-prod spikes deleted
  (private/, gitignored); 5 older spikes lack README.md (soon —
  scaffold via scripts/new_spike.sh or delete after outcome review).
- §G.5 arch-spike pattern: OK.

No `block` findings. Scaffolding clean.

## Spec runner observable (HEAD `908414b2`)

```
[memory64           ] return=337 (pass=337 fail=0  ) trap=205 (pass=205 fail=0  ) invalid=83  (pass=83  fail=0) skip=0
[tail-call          ] return=31  (pass=31  fail=0  ) trap=0   (pass=0   fail=0  ) invalid=10  (pass=10  fail=0)
[exception-handling ] return=34  (pass=0   fail=34 ) trap=2   (pass=0   fail=2  ) invalid=7   (pass=5   fail=2  ) exception=4 (pass=0 fail=4)
[function-references] invalid=12  (pass=12 fail=0)
total: return pass=368 fail=34; trap pass=205 fail=2; invalid pass=110 fail=2; exception pass=0 fail=4
```

## Active task — open 10.G WasmGC bundle (next cycle)

Remaining Phase 10 IN-PROGRESS rows all gate on 10.G:
- **10.E** — blocked-by D-192 (exnref ValType is GC-territory per
  ADR-0114 line 217-218: ships only when ADR-0115/0116 ship).
- **10.R-4 / 10.R-5** — `(ref $sig)` typed-funcref is GC-territory
  per 10.R-1's note ("deferred to 10.G WasmGC").
- **10.G** itself — full GC heap+collector+RTT+i31 (ADR-0115/0116/
  0117 all Accepted 2026-05-25). Sub-tasks per ROADMAP §10 row:
  Value.anyref arm + Module.needs_gc_heap flag + needs_heap_detector
  + heap.zig + Collector vtable + regalloc stack-map axis +
  i31.zig + type_hierarchy + op_gc + op_i31 + collector_mark_sweep
  + gc_stress_runner + cross fixtures + spec corpus.

Next cycle: open bundle `10.G-foundation` with exit-condition
"`Value.anyref` arm + `Module.needs_gc_heap` parse-time flag land
(both additive, no impl-side consumer yet)" — that's the smallest
slice carving off the GC substrate before opening the larger
collector / op_gc work.

## Next sub-chunk candidates (names only)

- **10.G-foundation bundle** — active per above; opens with
  Value.anyref + needs_gc_heap (cycle 1 of ~10).
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
