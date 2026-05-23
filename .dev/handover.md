# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing discipline:
> [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Fresh-session start here

**Authoritative remaining-work source**:
[`.dev/phase9_close_master.md`](./phase9_close_master.md).

**Mandatory before any §9.x [x] flip**: run
`bash scripts/check_phase9_close_invariants.sh --gate`.

**Current gate state (mac-host invariants)**: 17/18 passed.
**windowsmini state (runtime, captured 2026-05-23 in
`/tmp/win.log`)**: 3 regressions surfaced; Phase 9 NOT closing.

## Active task — Win64 regression triage (from /tmp/win.log)

windowsmini `run_remote_windows.sh test-all` exit 253 at
`assert_exhaustion runaway ()` in `call/` manifest. Reached
fixtures show **3 distinct Win64 bugs**, in this order:

1. **R1 — `br: type-f64-f64-value(())`** (line 2238)
   - Got: `(f64:0x4014000000000000, f64:0x00007ff6baf00000)`
   - Expected: `(f64:4.0, f64:5.0)`
   - First f64 correct; **second is uninit pointer-shaped
     (0x7ff6...)**. Class: Phase 2'a–2'l Win64 multi-result
     2-int register-class wrapper bug. Body's register_write
     epilogue likely not writing result 1 to RDX on Win64
     (SysV-only mapping); wrapper reads garbage.

2. **R2 — `br: as-return-values(())`** (line 2239)
   - Got: `(i32:2, i64:330762767128)`
   - Expected: `(i32:2, i64:7)`
   - Same class as R1.

3. **R3 — `assert_exhaustion runaway ()` in `call/`** (line
   2629) → runner exit 253. **D-162 supposedly closed by
   ADR-0105 (`7c1ec732`)** but the JIT-prologue stack-probe
   doesn't actually fire on Win64 — stack overflow still
   crashes the runner. SKIP-WIN64-EXHAUSTION arm was removed
   (`d-162`) without windowsmini runtime verification.

4. **D-163 status: UNKNOWN** — runner died at R3 BEFORE
   reaching `call/call.0.wasm`'s D-163 fixture. Re-run only
   after R1/R2/R3 fix.

## Next session action plan

**Triage order: R3 → R1+R2 → re-run → D-163**.

**R3 cycle 1-3 evidence (2026-05-23)**:
- Cycle 1: computeStackLimit returns sane non-zero on Win64.
- Cycle 2: INT 3 at trap stub top; exit code stayed 253. Probe
  never reaches stub (reverted with broken paired test).
- Cycle 3 (`/tmp/win.log:4251`): per-call diag at
  `assert_exhaustion runaway`:
  `stack_limit=0x12bd204000 sp=0x12be1f7fa0 margin=0xff3fa0`
  — runaway entered with ~16 MiB margin yet crashed exit 253.
  Probe genuinely never fires despite huge margin. Cause is
  in bucket "JBE patch off / R15 stale / `stack_limit_off`
  layout drift" per cycle-3 decision tree.

**Active chunk** (architectural / R3 cycle 4): extend `diagOnce`
into `diagOnceWithRt(rt, off, val)` that ALSO reads
`*(rt + stack_limit_off)` via raw pointer cast and prints as
`via_off=0x...`. Three outcomes:

- `via_off == stack_limit_value` → layout correct AND `rt` valid
  in Zig context → bug is in JIT-side probe encoding (JBE patch
  off / R15 actually stale at runtime / instruction encoding).
- `via_off != stack_limit_value` → offset/layout drift on Win64
  build despite `extern struct` discipline.

After R3 root cause: R1/R2 (Phase 2 Win64 2-int register-class
— `op_control.zig::marshalReturnRegs` likely SysV-only) →
re-run → D-163 (spike H1/H2/H3 in
`private/spikes/d-163-win64-call-indirect-trap/`).

windowsmini SSH-reachable per ADR-0049; autonomous-eligible.
`bash scripts/run_remote_windows.sh test-all` re-kicked each
cycle → `/tmp/win.log`.

## Work landed this session (2026-05-23)

ADR-0106 cycle 3e Phase 2'a→2'l full chain; D-094 + D-164 closed
(Mac/Linux); SKIP-WIN64-MULTI-RESULT arm removed. R3 cycles 1+2:
diagnostic + INT 3 trap-stub sentinel rule out `stack_limit=0`
and trap-stub epilogue bug; probe genuinely never reaches stub.

## See

- `/tmp/win.log` (windowsmini test-all result; 17703 lines).
- [`phase9_close_master.md`](./phase9_close_master.md) §5.1.
- `private/spikes/d-163-win64-call-indirect-trap/`.
- ADR-0104 / 0105 / 0106 / 0078.
- `.dev/lessons/2026-05-23-wrapper-thunk-stack-save-not-callee-saved.md`.
