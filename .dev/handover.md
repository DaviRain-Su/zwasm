# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Fresh-session start here

**Authoritative remaining-work source**:
[`phase9_close_master.md`](./phase9_close_master.md) (now
amended with §5.3a Phase 9 真スコープ expansion).

**Mandatory before any §9.x [x] flip**:
`bash scripts/check_phase9_close_invariants.sh --gate`.

**Gate state (mac-host)**: 18/18 passed.
**windowsmini state (2026-05-23 cycle 8 reconcile,
HEAD=84d4f1eb)**: D-163 PASS (`call: assert_trap
as-call_indirect-last` ran through normal trap dispatch
without FAIL/SKIP/crash; `/tmp/win.log` line 14615). fac-rec
exhaustion still hangs → reconcile timed out (exit 1).

## Phase 9 close blockers (current; ADR-0104 Revision 2026-05-23)

5 outstanding items:

1. **D-165** — Win64 fac-rec i64-shape probe-fire divergence.
   Under **interactive investigation with user** (lldb /
   custom small-input bisect; not autonomous-friendly).
   Spike: `private/spikes/d-165-win64-fac-rec-hang/`.
2. **D-157** (Phase 9 真スコープ, §5.3a) — extend
   `runtime/instance/instantiate.zig` to verify
   table / memory / global import-type at bind time. 56
   Wasm 2.0 `assert_unlinkable` fixtures stop emitting
   `SKIP-NO-LINK-TYPECHECK`.
3. **D-079 (ii)** (Phase 9 真スコープ, §5.3a) — extend
   `Runtime.globals: []*Value` (ADR-0052 §3 scalar-only) to
   v128-aware via per-entry width carried in
   `globals_offsets/valtypes`; plumb into `instantiate.zig`
   cross-module import wiring. Paired in-source test in
   `src/api/instance.zig`.
4. **D-139** (Phase 9 真スコープ, §5.3a) — audit c_api
   Instance behaviours lacking spec-corpus coverage; route
   spec_assert through c_api OR add per-c_api-feature
   in-source tests in `src/api/instance.zig`.
5. **§9.13** collab review (hard gate) — ADR-0105 + ADR-0106
   `Proposed → Accepted` flip. User-gated.

## Closed this session (2026-05-23)

- ✅ **R3 / D-162**, **R2**, **R1**, **D-094**, **D-164**.
- ✅ **D-163** SKIP-WIN64-CALL-INDIRECT-TRAP arm retired
  (`0de438a6`); windowsmini cycle 8 verified PASS. Root
  cause: R3 stack-probe broader trap-path fix; codegen-bug
  spike was unnecessary.
- ✅ **D-165 cycles 2-6** byte-shape + diagnostic ladder
  (`0fe14a5f`, `a5f7236b`, `8c7f3d48`, `f1d823ec`); cycle 6
  proved Win64 probe fires for void shape (runaway count=1)
  but not for i64 shape (fac-rec hangs); cycle 7 filed
  formal D-165 debt row + lesson.

## Cycle 9 (next session) recommended next step

Per user direction 2026-05-23, **D-165 stays for interactive
session** (lldb / batch script / windowsmini-side
investigation). The autonomous loop's next chunks:

- **D-157 implementation** — autonomous-eligible. Extend
  `runtime/instance/instantiate.zig` non-func import-type
  checking. Mac + ubuntu test-all gate. Exit: 0
  `SKIP-NO-LINK-TYPECHECK` on Mac + ubuntunote.
- **D-079 (ii) implementation** — autonomous-eligible.
  Extend Runtime.globals + cross-module wiring + in-source
  test.
- **D-139 audit** — autonomous-eligible. Doc + paired tests.

windowsmini reconcile deferred per ADR-0049 — final phase-
boundary verification AFTER D-165 + above 3 land.

windowsmini SSH-reachable, autonomous-eligible per ADR-0049.

## See

- [`phase9_close_master.md`](./phase9_close_master.md) §5.3a + §6.
- ADR-0104 Revision 2026-05-23 (scope expansion).
- `.dev/debt.md` D-157 / D-079 / D-139 / D-165.
- `.dev/lessons/2026-05-23-win64-i64-shape-probe-divergence.md`.
- `/tmp/win.log` line 14615 (D-163 evidence).
