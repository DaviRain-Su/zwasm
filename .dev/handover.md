# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Fresh-session start here

**Authoritative remaining-work source**:
[`phase9_close_master.md`](./phase9_close_master.md).

**Mandatory before any §9.x [x] flip**:
`bash scripts/check_phase9_close_invariants.sh --gate`.

**Gate state (mac-host)**: 17/18 passed.
**windowsmini state (2026-05-23 `/tmp/win.log`)**:
`assert_exhaustion fac-rec i64:1073741824` hangs after
`fac : assert_return fac-ssa` (line ~28527).

## Active chunk — D-165 cycle 4 (Win64 fac-rec hang spike)

Phase 9 close gate: I1 = SKIP-WIN64-CALL-INDIRECT-TRAP.
Blocking sequence: **D-165 → D-163 → §9.13-0 → Phase 9 DONE**.

Spike: `private/spikes/d-165-win64-fac-rec-hang/`.

### Hypotheses (per `hypothesis_enumeration.md`)

1. ~~Probe doesn't fire (frame_bytes=0)~~ — REJECTED cycle 1
   (Win64 shadow space forces `frame_bytes ≥ 56`).
2. ~~`stack_limit = 0` globally~~ — REJECTED cycle 1 by analogy.
3. ~~Byte-shape regression in i64-result emit~~ — REJECTED
   cycle 2 (`0fe14a5f`) and refined cycle 3 (`e6a56734`). Unit
   test `compile: self-recursive (i64)->i64 — probe + i64-
   result marshal` asserts JBE-patched + SUB RSP ≥ 48 (Win64) /
   ≥ 16 (SysV) + REX.W MOV r64,RAX post-CALL + MOV
   entry_arg0_gpr,runtime_ptr_save_gpr pre-CALL. PASS on Mac
   SysV native + Win64 cross-build clean.
4. ~~Trap-flag propagation stall (host-side)~~ — REJECTED
   cycle 3 by read of `src/engine/codegen/shared/entry.zig:
   162-175` `invokeAndCheck`: BOTH `callI64_i64` and
   `callI32NoArgs` flow through this helper which clears
   `rt.trap_flag = 0` pre-call and returns `Error.Trap` on
   non-zero post-call. Same path on Win64.
5. (active, **leading**) Probe fires correctly on Win64 but
   the recovery path interacts with Win64 commit-region
   geometry such that trap_stub's `POP R15; POP RBP; RET`
   sequence faults on a guard-page boundary AND VEH no longer
   handles `EXCEPTION_STACK_OVERFLOW` (per ADR-0105 D4 removal,
   `windows_traphandler.zig:157`). Signature: process hangs in
   default OS exception handling. Probe: instrument trap stub
   with a counter at [R15 + diagnostic_off] OR enable
   `diagOnceWithRt` print in trap stub; rerun on windowsmini;
   observe whether trap stub fires for fac-rec.

### Cycle 4 plan (runtime instrumentation)

Static analysis exhausted (3-cycle cap reached; H1-H4 rejected).
Cycle 4 lands **runtime instrumentation** for windowsmini:

1. Add `trap_stub_entry_count: u32` to `JitRuntime`; emit
   `INC DWORD PTR [R15+off]` as first inst in trap stub
   (op_control.zig:1334+). Mac/Linux paths unchanged.
2. Surface counter via `invokeAndCheck` diagnostic.
3. Push; reconcile via `bash scripts/run_remote_windows.sh
   test-all`. Observe:
   - count > 0, flag=0 → flag-write lost.
   - count = 0 → probe never fires (revisit H1 with evidence).
   - count > 0, flag=1 → unwind cost hypothesis.

### After D-165 resolved

Remove `SKIP-WIN64-CALL-INDIRECT-TRAP` arm in
`spec_assert_runner_base.zig:3088`, re-run windowsmini,
observe `call: assert_trap as-call_indirect-last ()`. If
PASS → D-163 closed; flip I1; gate exits 0; flip §9.13-0 [x]
→ Phase 9 DONE.

## Closed this session (2026-05-23)

- ✅ **R3 / D-162**, **R2**, **R1** (Win64 stack-probe / cap /
  wrapper); D-094, D-164 (multi-result ABI).
- ✅ **D-165 cycle 2** byte-shape test (`0fe14a5f`).
- ✅ **D-165 cycle 3** arg-marshal extension (`e6a56734`) +
  H4 ruled out via entry.zig read.

windowsmini SSH-reachable, autonomous-eligible per ADR-0049.

## See

- `/tmp/win.log` (windowsmini test-all; 17703 lines).
- `private/spikes/d-165-win64-fac-rec-hang/ANALYSIS_REFINED.md`.
- [`phase9_close_master.md`](./phase9_close_master.md) §5.1.
- ADR-0104 / 0105 / 0106 / 0078.
