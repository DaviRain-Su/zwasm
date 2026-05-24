# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: 9 IN-PROGRESS. **§9.12-F `[x]`** + **§9.12-I `[x]`**
  — Phase D + Phase C both closed.
- **Last commit**: §9.12-F flip (this cycle) — all 6 cohort
  debts verified discharged: D-094, D-090, D-062, D-141, D-081,
  D-055.
- **Phase 9 close gate (mac-host)**: **18/18 PASS**.
- **Remaining `[ ]` in §9**: only §9.13-0 + §9.13 (hard gate).

## Active task — §9.13-0 close blocker investigation

§9.13-0 exit per row text requires (per ADR-0104 Revision
2026-05-23): D-162 ✅, D-163 ✅, D-164 ✅, D-157 ✅, D-139 ✅,
**D-079 (ii) ❌ blocker remaining**.

**D-079 (ii) status**: barrier "ADR-0110 implementation" was
dissolved (Phase A done at `9204847a`), but cycle 46 surfaced
D-170 ("c_api `wasm_instance_new` v128 globals JIT-execution
gap") — the actual fix wasn't auto-included in Phase A.4. Both
debts describe the same c_api-Instance v128 cross-module gap.

**Next chunk decision** (autonomous):
- **Option A**: investigate D-170 tractability — audit
  `wasm_instance_new` → JitRuntime construction path; if Phase
  A.4g's uniform 16-byte stride makes the fix small (~50-100
  LOC), discharge D-170 (closes §9.13-0).
- **Option B**: if D-170 is genuinely Phase 10+ scope
  (requires ADR-0109 / new design), file ADR-0104 amendment
  removing D-079(ii) from §9.13-0 scope + cite D-170 as Phase
  10+ deferral. Then §9.13-0 can flip `[x]`.

Pick A first (cheap to investigate; if intractable, fall back
to B). Then Phase E (§9.13 hard gate, **user collab**) →
Phase F (Phase 10 open).

## Cold-start procedure

Per `/continue` SKILL.md Resume Steps 0.5 / 0.7 / 0.8.
Authoritative remaining-work source:
[`phase9_remaining_flow.md`](./phase9_remaining_flow.md) §2.

**Mandatory before any §9.x [x] flip**:
`bash scripts/check_phase9_close_invariants.sh --gate`
(currently 18/18 PASS at `526bbe30`).

## See

- ADR-0104 (Phase 9 真スコープ)
- ADR-0110 — Value widen 8→16, Closed (implemented) at `9204847a`
- ADR-0105 / ADR-0106 — Closed (implemented); I6 invariant
  widened to accept Closed alongside Accepted per Phase C
- D-167 discharged at `4339eb02`/`fe666b0f` (Phase B.1)
- D-174 cascade fix at `57039f10` (Phase B.3 sub)
- D-139 audit + 7 tests at `64c2378c`…`f81234b0` (Phase B.3)
- D-171 / D-172 / D-173 — c_api accessor blockers (v0.1.0 RC)
- [`c_api_instance_audit_2026-05-24.md`](./c_api_instance_audit_2026-05-24.md)
  — D-139 audit (closed; §6 revision history)
- [`phase9_remaining_flow.md`](./phase9_remaining_flow.md) §2
  Phase D/E/F sequence reference
