# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: 9 IN-PROGRESS. §9.13-V `[x]`; Phase B.1 in flight.
- **Last commit**: `4339eb02` — D-167 wire-up (Win64 1+arg multi-
  result entry helpers; `invokeBufWin64Args` helper + 4 Win64
  if-arms in entry.zig).
- **Phase 9 close gate (mac-host)**: **18/18 PASS**.
- **Test state**: Mac aarch64 test-all GREEN at `4339eb02`;
  cross-Win64 build (`-Dtarget=x86_64-windows-gnu`) GREEN; lint
  GREEN. ubuntu test-all GREEN at `6db998e2` (verified prior
  cycle 0.7); ubuntu kick for `4339eb02` in flight (background).
  windowsmini integration verify for D-167 wire-up: in flight.

## Active task — Phase B.1 (D-167 windowsmini verify)

Wire-up landed at `4339eb02`. Verification in flight:
`bash scripts/run_remote_windows.sh test-all > /tmp/win.log 2>&1`
expected to flip the pre-existing 9 Win64 directive fails (D-167
class) toward 0. Two possible outcomes for next cycle:

- **All 9 → 0**: discharge D-167 (`chore(debt): close D-167 ...`),
  proceed to B.2 (D-028 IPC flake verify).
- **Partial / new failure shape**: file the residual as a refined
  D-167 sub-row or new debt, decide between additional wire-up
  vs spike investigation.

Phase B remaining after B.1:

- **B.2** — D-028 IPC flake CONFIRMED #5 final verify (N=4 more
  silent runs post-Windows-Defender fix; per
  `.claude/rules/heisenbug_discharge.md`)
- **B.3** — D-139 c_api Instance audit + coverage

After Phase B → Phase C (ADR canonical pass) → Phase D
(§9.12-F debt verify) → Phase E (§9.13 hard gate, user collab) →
Phase F (Phase 10 open).

## Cold-start procedure

Per `/continue` SKILL.md Resume Steps 0.5 / 0.7 / 0.8.
Authoritative remaining-work source:
[`phase9_remaining_flow.md`](./phase9_remaining_flow.md) §2.

**Mandatory before any §9.x [x] flip**:
`bash scripts/check_phase9_close_invariants.sh --gate`
(currently 18/18 PASS at `9204847a`).

## See

- ADR-0104 (Phase 9 真スコープ)
- ADR-0110 — Value widen 8→16, **Closed (implemented) at `9204847a`**
- [`phase9_remaining_flow.md`](./phase9_remaining_flow.md) §2
  Phase B/C/D/E/F sequence
- [`phase9_value_widen_plan.md`](./phase9_value_widen_plan.md)
  — §9.13-V Phase A.1-A.6 closed; transitions to ARCHIVED at
  Phase 10 open
- Debt: D-167 (`now`, Phase B.1), D-028 (`blocked-by`, Phase B.2),
  D-170 (`blocked-by` Phase 10+ alongside ADR-0109)
- §9.13-V closed-cohort cycles 38-56: `git log --grep="§9.13-V"`
  (28 commits on the linear chain to `9204847a`).
