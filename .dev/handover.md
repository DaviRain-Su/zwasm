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

## Active chunk — D-165 cycle 2 (Win64 fac-rec hang spike)

Phase 9 close gate: I1 = SKIP-WIN64-CALL-INDIRECT-TRAP.
Blocking sequence: **D-165 → D-163 → §9.13-0 → Phase 9 DONE**.

Spike: `private/spikes/d-165-win64-fac-rec-hang/`
(SURVEY.md = cycle-1 subagent; ANALYSIS_REFINED.md =
cycle-1 static-analysis corrections).

### Hypotheses (per `hypothesis_enumeration.md`)

1. ~~Probe doesn't fire (frame_bytes=0)~~ — REJECTED cycle 1
   via `emit_setup.zig:104-111` read: Win64 shadow space
   forces `frame_bytes ≥ 56`; probe IS reachable.
2. ~~`stack_limit = 0` globally~~ — REJECTED by analogy:
   runaway PASSes on cycle 8 with the same runner.
3. (active, **leading**) Post-CALL marshal regression from
   R1/R2/R3 diff. Signature: Win64 `marshalReturnRegs` or
   wrapper-thunk arm handles single-i64-result trap-return
   with pre-cap=1 semantics. Probe: cross-build to
   `x86_64-windows-gnu`, Mac-host unit test inspects emitted
   bytes for fac-rec's prologue probe + post-CALL marshal +
   trap stub (no windowsmini round-trip).
4. (active) Trap-flag propagation stall for single-i64-result
   Win64. Signature: `rt.trap_flag = 1` set but runner's
   post-call check reads i64 result before checking the
   flag. Probe: read wasm/jit entry shim for single-i64-
   result Win64 path.
5. (active) Cumulative unwind cost ≥ runner timeout.
   Signature: 13K-frame unwind crosses commit regions
   per-frame; external wall-clock timeout fires, not a true
   infinite loop. Probe: instrument unwind frame count OR
   bisect fac-rec input on windowsmini.

### Cycle 2 plan

1. Add `test "Win64 fac-rec prologue + post-CALL marshal +
   trap stub byte sequence"` to
   `src/engine/codegen/x86_64/emit_test_int.zig`. Mac-host
   gate; classifies as `substrate`.
2. Test: parse fac.0.wasm → force `abi.current_cc = .win64`
   → emit func 0 → assert byte signatures (CMP RSP
   [R15+stack_limit_off], JBE rel32, jit_executed_flag
   write, SUB RSP ≥ 56, CALL self, trap-stub tail).
3. PASS → H3 narrows to runtime/OS interaction; cycle 3
   moves to H4 entry-shim read. FAIL → diff reveals
   regression site.

### After D-165 resolved

Remove `SKIP-WIN64-CALL-INDIRECT-TRAP` arm in
`spec_assert_runner_base.zig:3088`, re-run windowsmini,
observe `call: assert_trap as-call_indirect-last ()`. If
PASS → D-163 closed by broader trap-path repair; flip I1
to OK; gate exits 0; flip §9.13-0 [x] → Phase 9 DONE.

## Closed this session (2026-05-23)

- ✅ **R3 / D-162** Win64 stack-probe headroom
  (`1e2d716d`). Lesson:
  `.dev/lessons/2026-05-23-win64-stack-probe-headroom.md`.
- ✅ **R2** Win64 `marshalReturnRegs` cap=1→2 (`aac986d9`).
- ✅ **R1** Win64 wrapper 2-XMM + `callF64f64NoArgs`
  (`73bcf80f`).

windowsmini SSH-reachable, autonomous-eligible per ADR-0049.

## See

- `/tmp/win.log` (windowsmini test-all; 17703 lines).
- `private/spikes/d-165-win64-fac-rec-hang/ANALYSIS_REFINED.md`.
- [`phase9_close_master.md`](./phase9_close_master.md) §5.1.
- ADR-0104 / 0105 / 0106 / 0078.
