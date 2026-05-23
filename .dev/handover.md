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

## Active chunk — D-165 cycle 6 (windowsmini reconcile + bisect)

Phase 9 close gate: I1 = SKIP-WIN64-CALL-INDIRECT-TRAP.
Blocking sequence: **D-165 → D-163 → §9.13-0 → Phase 9 DONE**.

Spike: `private/spikes/d-165-win64-fac-rec-hang/`.

### Hypotheses (per `hypothesis_enumeration.md`)

1. ~~Probe doesn't fire (frame_bytes=0)~~ — REJECTED cycle 1.
2. ~~`stack_limit = 0` globally~~ — REJECTED cycle 1.
3. ~~Byte-shape regression in i64-result emit~~ — REJECTED
   cycle 2 + 3.
4. ~~Trap-flag propagation stall (host-side)~~ — REJECTED
   cycle 3 via `entry.zig:162-175`.
5. (active, **leading**) Probe-fire interaction with Win64
   commit-region geometry. Diagnostic ladder landed cycles 4+5:
   - cycle 4 (`8c7f3d48`): `JitRuntime.trap_stub_entry_count`
     u32 + INC at x86_64 stack-overflow trap stub start.
   - cycle 5 (`7624019f`): `invokeAndCheck` prints
     `[d-165] kind=4 cumulative_trap_stub_entry_count=N` on
     Error.Trap with kind=4.

### Cycle 6 plan (runtime evidence)

1. Run windowsmini reconcile against HEAD:

   ```sh
   bash scripts/run_remote_windows.sh test-all > /tmp/win.log 2>&1
   ```

2. After test-all completes (or aborts at fac-rec hang), grep:

   ```sh
   grep '\[d-165\]' /tmp/win.log | head -50
   ```

3. Read the cumulative count for runaway PASS (confirms Win64
   probe works) and for any other assert_exhaustion fixture
   that reaches the print.

4. If fac-rec still hangs: write a custom `.wast` fixture with
   smaller exhaustion input (1M, 100K, 10K) to bisect the
   threshold between probe-fires-correctly and hang.

windowsmini reconcile is the Phase-9-close boundary action;
per the close-plan override (handover Step 1a), D-165 runtime
verification supersedes the per-chunk ADR-0049 forbid for this
specific work.

### After D-165 resolved

Remove `SKIP-WIN64-CALL-INDIRECT-TRAP` arm in
`spec_assert_runner_base.zig:3088`; re-run windowsmini; if PASS
→ D-163 closed; flip I1; gate exits 0; flip §9.13-0 → Phase 9
DONE.

## Closed this session (2026-05-23)

- ✅ **R3 / D-162**, **R2**, **R1**, **D-094**, **D-164**.
- ✅ **D-165 cycles 2-3** byte-shape tests (`0fe14a5f` +
  `a5f7236b`); H3, H4 ruled out.
- ✅ **D-165 cycle 4** `trap_stub_entry_count` JIT diagnostic
  (`8c7f3d48`); size 232 → 240.
- ✅ **D-165 cycle 5** kind=4 stderr surface (`7624019f`).

windowsmini SSH-reachable, autonomous-eligible per ADR-0049.

## See

- `/tmp/win.log` (windowsmini test-all; 17703 lines).
- `private/spikes/d-165-win64-fac-rec-hang/ANALYSIS_REFINED.md`.
- [`phase9_close_master.md`](./phase9_close_master.md) §5.1.
- ADR-0104 / 0105 / 0106 / 0078.
