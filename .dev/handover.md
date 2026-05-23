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

## Active chunk — D-165 (Win64 fac-rec hang spike)

Phase 9 close gate: invariants 17/18 (I1 = SKIP-WIN64-CALL-
INDIRECT-TRAP). Blocking sequence: **D-165 → D-163 → §9.13-0
[x] flip → Phase 9 DONE**.

**Immediate next action**: investigate D-165. windowsmini
test-all stalls at `assert_exhaustion fac-rec i64:1073741824`
(the directive right after `fac : assert_return fac-ssa`,
line ~28527 in /tmp/win.log from the cycle-8 run).

Concrete spike steps (no Step 0 survey — root-cause hunting):

1. Write a Mac-host unit test that compiles a Wasm `fac-rec`-
   shape `(func (param i64) (result i64))` recursive body and
   directly executes it via the JIT (Mac aarch64 first to
   verify the test scaffold). Probe should fire at depth
   ~16K (1 MiB / 64 bytes).
2. Cross-build for `x86_64-windows-gnu` and `objdump -d` the
   emitted prologue + body + trap stub. Compare against the
   `runaway` shape (which works) — diff the byte sequences.
3. If bytes look identical to runaway's structure → hang is
   in some Win64 runtime interaction (VEH, thread state).
   Bisect by reducing the fac-rec input from 1073741824 to
   a small value (e.g. 100) and see if it changes behavior.
4. If bytes differ from runaway → diff isolates the bug
   site. Likely candidates: i64-result regalloc, post-CALL
   marshal, recursive-call sig validation.

Hypotheses for what differs vs runaway:
- (a) Probe doesn't fire for i64-param/i64-result functions
  (regression of probe gating?).
- (b) Trap stub leaves stack in wrong state for i64-result
  caller; post-trap unwind hangs.
- (c) Recursion never traps — fac-rec has small per-call
  frame but the multi-billion input still saturates somehow.

After D-165 resolved: remove `SKIP-WIN64-CALL-INDIRECT-TRAP`
arm in `spec_assert_runner_base.zig:3088`, re-run windowsmini,
observe `call: assert_trap as-call_indirect-last ()` outcome.
If PASS → D-163 closed by R3 fix's broader trap-path repair;
flip I1 to OK; check_phase9_close_invariants.sh exits 0; flip
§9.13-0 [x] → Phase 9 DONE.

## Closed this session (2026-05-23)

- ✅ **R3 / D-162** (`assert_exhaustion runaway` Win64 crash):
  Win64 commit-pattern early-overflow root cause. Fix:
  `STACK_GUARD_HEADROOM = 1 MiB` on Win64 only (`1e2d716d`).
  Lesson: `.dev/lessons/2026-05-23-win64-stack-probe-headroom.md`.
- ✅ **R2** (`br: as-return-values (i32, i64)`): Win64 cap=1 →
  cap=2 in `op_control.zig::marshalReturnRegs` (`aac986d9`).
- ✅ **R1** (`br: type-f64-f64-value (f64, f64)`): wrapper
  2-XMM branch in `emitX8664Win64` + Win64 routing in
  `callF64f64NoArgs` (`73bcf80f`). Verified PASS on
  windowsmini cycle-8 log.

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
