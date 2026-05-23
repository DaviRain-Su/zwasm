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

**Triage**: R3 → R1+R2 → re-run → D-163.

**R3 cycle 1-5 evidence (2026-05-23)**:
- C1-3: stack_limit sane (~16 MiB margin at runaway); probe
  never reaches trap stub (INT 3 sentinel showed exit 253
  unchanged).
- C4: `via_off==stack_limit==0x7cb4804000`, off=224 — layout,
  offset, rt validity all correct.
- C5: host-runnable JBE-patch test PASSED on Win64 (Build
  Summary 1708/1753, 0 fails). Encode-time patch is correct;
  probe genuinely fails at runtime despite correct bytes.

**Active chunk** (architectural / R3 cycle 6): bump
`STACK_GUARD_HEADROOM` from 16 KiB to **1 MiB on Win64 only**.
Hypothesis: Windows raises `EXCEPTION_STACK_OVERFLOW` BEFORE SP
reaches `low + 16K` due to commit-pattern early-overflow.
A 1 MiB headroom guarantees the probe fires well before any
Windows commit boundary.

Outcomes for next windowsmini run:
- runaway PASSES → commit-pattern hypothesis confirmed; land
  lesson + tune headroom permanently (no ADR change since D6
  said "tunable per amend").
- runaway STILL crashes 253 → bug is in probe instruction
  stream execution itself (last hypotheses exhausted; needs
  user-driven windbg / disasm investigation).

After R3: R1/R2 (Win64 `marshalReturnRegs` Cc-aware fix) →
re-run → D-163 (spike H1/H2/H3 in
`private/spikes/d-163-win64-call-indirect-trap/`).

windowsmini SSH-reachable, autonomous-eligible per ADR-0049.

## Work landed this session (2026-05-23)

ADR-0106 Phase 2'a→2'l; D-094/D-164 closed (Mac/Linux). R3 5+
diagnostic cycles ruled out stack_limit=0, layout drift, JBE
patch off, encoder bug.

## See

- `/tmp/win.log` (windowsmini test-all result; 17703 lines).
- [`phase9_close_master.md`](./phase9_close_master.md) §5.1.
- `private/spikes/d-163-win64-call-indirect-trap/`.
- ADR-0104 / 0105 / 0106 / 0078.
- `.dev/lessons/2026-05-23-wrapper-thunk-stack-save-not-callee-saved.md`.
