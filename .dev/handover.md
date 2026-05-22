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

1. **R3 (ADR-0105 Win64)**: investigate why JIT-prologue
   stack-probe doesn't fire on Win64. Likely cause: stack_limit
   not set, or comparison instruction wrong on Win64, or VEH
   STACK_OVERFLOW filter still firing pre-probe. Check
   `src/platform/stack_limit.zig` + `emit.zig` Win64 prologue
   probe emission. Likely 1-cycle fix.

2. **R1/R2 (Phase 2 Win64 2-int register-class)**: the
   wrapper Win64 (Phase 2'i, 33 bytes) assumes body writes
   result 1 to RDX. Verify body's register_write epilogue
   actually writes RDX on Win64 — cycle 2c's marshalReturnRegs
   may be SysV-only. Likely a Cc-aware fix in
   `src/engine/codegen/x86_64/op_control.zig::marshalReturnRegs`.

3. After R1/R2/R3 land + windowsmini re-runs green except
   D-163: focus on D-163 spike's H1/H2/H3 probes (per
   `private/spikes/d-163-win64-call-indirect-trap/`).

windowsmini is SSH-reachable (verified 2026-05-23). Per ADR-0049
investigation work is autonomous-eligible. `bash scripts/
run_remote_windows.sh test-all` can be re-kicked after each
fix; result lands in `/tmp/win.log`.

## Work landed this session (2026-05-23)

ADR-0106 cycle 3e Phase 2'a → 2'l full implementation chain;
D-094 + D-164 closed (Mac/Linux); SKIP-WIN64-MULTI-RESULT arm
removed. Mac aarch64 + Linux x86_64 green. **Win64 runtime
NOT verified during the cycle** — surfaced as R1/R2/R3 here.

## See

- `/tmp/win.log` (windowsmini test-all result; 17703 lines).
- [`phase9_close_master.md`](./phase9_close_master.md) §5.1.
- `private/spikes/d-163-win64-call-indirect-trap/`.
- ADR-0104 / 0105 / 0106 / 0078.
- `.dev/lessons/2026-05-23-wrapper-thunk-stack-save-not-callee-saved.md`.
