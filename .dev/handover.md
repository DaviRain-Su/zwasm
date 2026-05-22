# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing discipline:
> [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Fresh-session start here

**Authoritative remaining-work source**:
[`.dev/phase9_close_master.md`](./phase9_close_master.md).

**Mandatory before any §9.x [x] flip**: run

```sh
bash scripts/check_phase9_close_invariants.sh --gate
```

(per `.claude/skills/continue/SKILL.md` Resume Step 5d + ADR-0104
+ `.claude/rules/phase9_close_invariants.md` §"Forbidden edits").

**Current gate state**: **FAIL 5/18** (13 OK: I2×4 + I3×5 + I4 + I5
+ I7×2). I2 c_api tests + I3 Zig facade landed 2026-05-23 cycle;
remaining FAILs are all I6 (2 user-gated ADRs) and I1 (3
SKIP-WIN64 arms, blocked by I6 implementations).

## Bucket-3 stop — user touchpoint required

All autonomous prep walked; loop stops without re-arm.

**Gating user touchpoint(s)**:

- **ADR-0105** ([`0105_jit_prologue_stack_probe.md`](./decisions/0105_jit_prologue_stack_probe.md))
  — `Status: Proposed → Accepted` flip at §9.13 hard gate
  review. After flip + impl (3 cycles per ADR-0105 §"Implementation
  plan"), I1 `SKIP-WIN64-EXHAUSTION` removed; D-162 closes.
- **ADR-0106** ([`0106_multi_result_return_convention.md`](./decisions/0106_multi_result_return_convention.md))
  — `Status: Proposed → Accepted` flip **with path (a) buffer-write
  OR path (b) implicit-SRet selection**. After flip + impl (4–6
  cycles), I1 `SKIP-WIN64-MULTI-RESULT` removed; D-164 + D-094
  close.
- **D-163** (`SKIP-WIN64-CALL-INDIRECT-TRAP` codegen-bug spike)
  is non-ADR-gated but downstream of the codegen-bug
  investigation; surfaces after ADR-0105/0106 land.

**Autonomous prep walked this resume** (do not re-walk):

- ADR-0105 + ADR-0106 References §: comprehensive v1 +
  wasmtime + spec testsuite citations with line ranges. SHA
  backfill enrichment commit `97b2a2db` is the touchpoint.
  **Null result for further refs** — production-runtime
  survey already covers v1 + wasmtime; no third reference
  adds value.
- ADR-0106 path (a) vs (b) spike: **null result** — both
  paths have detailed implementation plans in the ADR
  itself; a spike would re-derive ADR content. User's
  selection at §9.13 is judgment over (a) simplicity vs (b)
  register-pair fast-path preservation, not data-gated.
- ADR-0105 spike: **not applicable** — single design path;
  spike would BE the on-branch impl gated on Accept.
- ADR-0105/0106 Consequences refinement: **null result** —
  Consequences sections detailed against current code state
  at draft (`6bfd0c8c`); no consequence has dissolved.

**To resume**: flip ADR-0105 + ADR-0106 Status to Accepted
(user collab review at §9.13 hard gate) and re-invoke
/continue. The autonomous loop will then pick up I1 SKIP arm
removal + JIT-prologue stack-probe + multi-result ABI
implementation per ADR-0104 D5 / D6.

## Work landed this session (2026-05-23 cycle)

- **I3** Zig facade `Runtime` / `Module` / `Instance` / `Value`
  + facade test in `src/zwasm.zig` (`6c4faeea`).
- **I2** 4 c_api Wasm-2.0 utilisation test blocks in
  `src/api/instance.zig` (`a35e0f21`): reftype round-trip,
  bulk-traps, mixed-exports walk, cross-module funcref.
- **§5.4** stale ADR/debt cleanup (`97b2a2db`): 5 ADR
  Revision history SHA backfills (ADR-0078 / 0103 / 0104 /
  0105 / 0106); D-007 / D-010 Phase target verification.
- **D-062** closed (this cycle, no commit yet) — barrier-
  dissolution check found arm64 v128 9th+ stack-arg already
  implemented at §9.9 / 9.9-f-3 = `80b2f1c5` (caller) +
  §9.9-e-1 (callee). Row removed from `debt.md`.

## Active `now` debts

(None — D-062 closed this cycle.)

## See

- [`phase9_close_master.md`](./phase9_close_master.md) (§5
  Tier 1; §6 exit predicate; §8 fresh-session entry).
- [ADR-0104](./decisions/0104_phase9_honest_accounting_reframe.md)
  (META reframe; Accepted).
- [ADR-0105](./decisions/0105_jit_prologue_stack_probe.md) +
  [ADR-0106](./decisions/0106_multi_result_return_convention.md)
  (Proposed; user-gated).
- [`.claude/rules/phase9_close_invariants.md`](../.claude/rules/phase9_close_invariants.md)
  (I1-I7 invariants + Forbidden edits).
- [`debt.md`](./debt.md): D-094 / D-164 (ADR-0104 reframed;
  blocked by ADR-0106 Accept).
