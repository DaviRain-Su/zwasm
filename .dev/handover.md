# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: 10.M cycle 67 — bulk-op (memory.copy / memory.fill /
  memory.init) memidx > 0 plumbing (lower + validator + interp).
  Baked `data0.wast` + `memory_copy0.wast`. Spec runner shows
  `[multi-memory] manifests=4 module=10 return=28 (pass=28 fail=0)
  trap=2 (pass=2 fail=0)` (up from manifests=2 return=9 last cycle).
  Mac aarch64 test-all + lint green (verified by exit code).
- **D-188 FULLY DISCHARGED** (cycle 61). **D-194 / D-195(c)**
  DISCHARGED earlier. Active debt rows: 16 — all `blocked-by:`;
  zero `now`.

## Active bundle

- None — 10.M autonomous continuation runs cycle-by-cycle without a
  formal bundle wrapper; each cycle yields its own observable delta.

## Active task — cycle 68: next autonomous chunk

Cycle 68 candidates (ordered by smallest red + observable delta):

1. **10.M continuation: bake more multi-memory fixtures** —
   Upstream `memory64/test/core/multi-memory/` has ~30 .wast; we have
   4 baked (load0, memory_size0, data0, memory_copy0). Candidates
   already-wired: `memory_init0` (memory.init memidx > 0; bulk-ops
   landed cycle 67), `memory_grow0` (memory.grow memidx > 0; landed
   cycle 66), `store0` (store memidx > 0; landed cycle 64),
   `align0` (align checks; load/store), `address0` (i32 vs i64
   addr). Pure infra; surfaces any remaining substrate gaps.
2. **D-195 sub-gap (b)** — cross-module `(register …)` runner
   registry. Sibling to D-192. Unblocks several instantiate-fail
   modules in EH + function-references + multi-memory corpora.
3. **10.E EH runtime path** — standalone EH return path
   (try_table.0). Multi-cycle.

Cycle 68 picks (1) by default — high-yield, low-risk pattern
established over cycles 64-67; each baked fixture is a self-contained
smoke test of the wired substrate. Pick `memory_init0` first (covers
the cycle-67 substrate's last untested op).

## Larger §10 work (blocked / later)

- **10.M memory64 multi-memory** — autonomous expansion in
  progress; substrate cycles 62-67 + corpus 65/66/67 baked. Most
  remaining work is bake-and-verify until specialised gaps surface.
- **10.E EH** — validator side spec-correct (cycle 61); runtime EH
  dispatch + cross-module register (D-192) external-gated.
- **10.G WasmGC** — D-179-blocked (wabt 1.0.41+).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (post-cycle-67)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass=7 fail=0) exception=4(fail4)
[function-references] return=39(fail36) trap=4(fail4) invalid=18(pass=18 fail=0)
[multi-memory       ] return=28 trap=2  (pass=28+2 fail=0)  <- +19+2 from memory_copy0 (cycle 67)
[wasm-3.0-assert    ] assert_return pass=396  assert_trap pass=207  assert_invalid pass=118 fail=0
```

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref +
  return_call_ref impl + typed-ref parser (D-195 sub-gap a).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- D-192 — EH return/trap fixtures blocked on cross-module register +
  exnref ValType.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0111 (memory64 + multi-memory design) — bundle anchor.
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- `.dev/lessons/2026-05-29-gate-tail-vs-exit-code.md` — gate
  verification discipline (exit code primacy).
- ROADMAP §10 row 10.M; `.dev/phase_log/phase10.md`.
