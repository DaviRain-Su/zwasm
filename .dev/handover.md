# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **13 IN-PROGRESS — C API full (wasm-c-api conformance)**. **Phase 12 (AOT) DONE** — §12.P closed
  (ADR-0141): `.cwasm` compile/run loader (§12.1) + JIT↔AOT differential (§12.2) + toolchain cross-compile
  (§12.3) + stateful-COMPUTE exec — globals/memory/tables/`call_indirect` (§12.3b) + cold-start ≥30% (§12.4:
  6/6 SIMD fixtures 33-37% AOT-faster). **Deferred to Phase 15**: §12.5 stack-map (co-defines with the GC
  `GcRootMap` shape, ADR-0141, with §11.4 rooting). **Deferred D-251**: WASI/host imports in AOT (parity with
  JIT compute-only, ADR-0140 — lands with JIT-WASI d-3 / D-244).
- **Phase 13 opened** (widget DONE/IN-PROGRESS flipped; §13 task table expanded). 🔒 is the END-of-phase
  wasm-c-api conformance gate, NOT an entry hard-gate — opened autonomously per the §12.P close.

## Next task (autonomous)

§13.1 — `wasm.h` surface audit (Step 0). Inventory the ~130 `wasm.h` functions; the C API already has a
working subset (`api/wasm.zig` + `cli/run.zig` drive engine/store/module/instance/func/extern/trap end-to-end).
Dispatch an Explore subagent: enumerate `wasm.h` (in `include/`) vs what `api/wasm.zig` implements; produce the
gap list grouped by category (valtype/functype/globaltype/tabletype/memorytype/ref/global/table/memory/extern/
trap/frame/foreign). That gap list drives §13.2 (implement missing, category-by-category, red→green). Then §13.3
(wasi.h + zwasm.h), §13.4 (`test/c_api_conformance/` fail=0), §13.5 (examples 3-OS), §13.P (🔒 conformance gate).

## Phase-12 close note (this turn)

§12.5 → Phase 15 + §12.P [x] + widget (ADR-0141). §12 row SHAs live inline in the row prose (richer than the
status-cell convention; grep-backfill was noisy). **audit_scaffolding** (mandatory phase-boundary) + the
**windowsmini 3-host reconcile** are this turn's close steps — see Step 0.7.

## Deferred / open debt (none a Phase-13 blocker)

- **§12.5 / §11.4** GC stack-map (AOT) + precise rooting → Phase 15 (ADR-0141 / ADR-0135; D-211).
- **D-251** WASI/host imports in AOT — with JIT-WASI d-3 (D-244); ADR-0140.
- **D-249** Windows bench timing (hyperfine on windowsmini) — perf-completeness, ADR-0137.
- **D-245** host→JIT callee-saved (win64 + arg'd remainder). **D-246** §11.3 arm64 dot/extmul → Phase 15.
- **D-238** x86_64-SysV cross-instance EH thunk. D-210/D-234/D-237/D-229/D-231/D-204/D-209/D-213 (note).

## Step 0.7 (next resume)

This turn = Phase-12 close (ADR-0141 + ROADMAP widget/§12.5/§12.P/§13-expand + handover). A **windowsmini
test-all 3-host reconcile** was kicked (§12.P phase-boundary discipline) → next resume `tail /tmp/win.log` for
OK (Phase-12 AOT exec skips Win64 via `skip.phaseEnd`; the reconcile + cross-compile gate cover the Win64
surface — no new Win64-exec paths). Last code HEAD verified ubuntu = `cf32e57a`; no new `src/` this turn (docs
only) → no ubuntu kick. **audit_scaffolding** ran this turn (phase-boundary mandatory) — findings in the close
commit / debt if any.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile: `zig build test
-Dtarget=x86_64-windows-gnu` (compile-only). 3-host reconcile = phase boundary.

## Key refs

- ROADMAP §13 (C API — Goal/exit + §13 task table); Phase Status widget (Phase 12 DONE / 13 IN-PROGRESS).
- ADR-0141 (Phase-12 close, §12.5→P15); ADR-0140 (WASI defer, §12.4 compute-scope); ADR-0139 (P12 re-sequence);
  ADR-0138 (`.cwasm` v0.2/0.3). `api/wasm.zig` + `include/wasm.h` = §13 surface. `cli/run.zig` drives the C API.
