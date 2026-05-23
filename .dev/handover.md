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

**Triage**: ✅ R3 closed → R1+R2 → re-run → D-163.

**R3 CLOSED (2026-05-23, cycle 6)**: Root cause = Windows
commit-pattern early-overflow. `EXCEPTION_STACK_OVERFLOW` fires
WAY before SP reaches `LowLimit + 16K` despite
`GetCurrentThreadStackLimits` returning correct reserved bounds.
Fix: bump `STACK_GUARD_HEADROOM` to 1 MiB on Win64 only
(`1e2d716d`). windowsmini evidence: `runaway` +
`mutual-runaway` both PASS on Win64 (per /tmp/win.log:31388 of
cycle-6 run). Mac+Linux unchanged. Lesson landed at
`.dev/lessons/2026-05-23-win64-stack-probe-headroom.md`.

**R1+R2 status**: ✅ **BOTH CLOSED** (verified
`/tmp/win.log:15477` cycle 8 — `br: type-f64-f64-value` and
`as-return-value` both PASS on windowsmini). R2 fixed by
cap=2 (`aac986d9`); R1 fixed by wrapper 2-XMM extension +
`callF64f64NoArgs` Win64 branch (`73bcf80f`).

**D-163 status**: SKIP-WIN64-CALL-INDIRECT-TRAP arm at line
16043 still fires. To verify post-R3 fix, remove SKIP arm
and observe — needs windowsmini round-trip. Blocked by D-165
(see below).

**D-165 (new)**: windowsmini test-all stalls at `fac` (~line
28K, after fac-ssa). Pre-existing pre-R3 (was hidden by
runaway crash). Multi-result fac fixture or follow-on test
hangs on Win64. Investigate as a separate spike before
D-163 verification can proceed.

After R3: R1/R2 (Win64 `marshalReturnRegs` Cc-aware fix) →
re-run → D-163 (spike H1/H2/H3 in
`private/spikes/d-163-win64-call-indirect-trap/`).

windowsmini SSH-reachable, autonomous-eligible per ADR-0049.

## Work landed this session (2026-05-23)

ADR-0106 Phase 2'a→2'l; D-094/D-164 closed (Mac/Linux). R3
CLOSED via 6 cycles → D-162 trap-on-Win64 fixed; root cause
(Windows commit-pattern early-overflow) captured in lesson.

## See

- `/tmp/win.log` (windowsmini test-all result; 17703 lines).
- [`phase9_close_master.md`](./phase9_close_master.md) §5.1.
- `private/spikes/d-163-win64-call-indirect-trap/`.
- ADR-0104 / 0105 / 0106 / 0078.
- `.dev/lessons/2026-05-23-wrapper-thunk-stack-save-not-callee-saved.md`.
