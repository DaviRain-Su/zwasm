# Session handover

> ≤ 80 lines. No numeric predictions
> ([`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).
> Framing discipline:
> [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Cold-start procedure — §9.13-0 close-plan override active

**Authoritative work source**:
[`.dev/phase9_13_0_close_plan.md`](./phase9_13_0_close_plan.md).
The `/continue` skill's Step 1a close-plan override
activates; follow that doc's §6 Work sequence. ADRs 0102 +
0103 flipped `Status: Proposed → Accepted` at `a6e3eb4f`;
bucket-3 gate dissolved. §0 preflight is a 10-canary check
(8 build tools + handle64 / Procmon64 — full Sysinternals
bundle at `711bdcce`).

## Active task — W4 retry 5 (new crash class investigation)

W4 retry chain summary (HEAD = `007e26e1`):

| Retry | HEAD | Result | Crash directive |
|---|---|---|---|
| 1 | `f73e7a98` | exit 253 zero output | unknown (no beacons) |
| 2 | `1567516e` | exit 1 | `assert_exhaustion runaway ()` |
| 3 | `09ee5bb9` | exit 29 (STACK_OVERFLOW filter active) | `assert_exhaustion runaway ()` (downstream re-fault) |
| 4 | `007e26e1` | exit 1 | `assert_trap as-call_indirect-last ()` (NEW class — earlier than D-162) |

Permanent value landed this chain: per-manifest beacon
(`ee7403ff`), per-directive beacon (`aeb01a23`), VEH
EXCEPTION_STACK_OVERFLOW filter (`09ee5bb9`), SKIP-WIN64-
EXHAUSTION + D-162 debt row + ADR-0078 taxonomy
(`007e26e1`).

**Next chunk** (W4 retry 5 investigation): the
`assert_trap as-call_indirect-last ()` crash class is distinct
from D-162. The fixture exercises `(call_indirect ... unreachable)`
in `call.0.wasm`. The wasm-1.0 spec_assert_runner ran 212 PASS
including its own `unreachable: assert_trap as-call_indirect-
last ()` directive, so the corpus path isn't intrinsically
broken — something about `call.0.wasm`'s module shape OR cumulative
state after 55 directives surfaces the bug. Candidates:

- Win64 `call_indirect` JIT codegen specific to call.0.wasm's
  type signatures (cross-checked: callI32NoArgs etc. work for
  wasm-1.0 runner, so NOT the entry-helper layer).
- Cumulative per-module state exhaustion (55 JIT invocations
  → FD / handle / stack pressure).
- Trap stub control-flow interaction with VEH's redirected
  recovery PC (the as-call_indirect-last fixture exercises
  unreachable-as-trap; VEH recovery may overlap with trap stub).

Next investigation: read `test/spec/wasm-2.0-assert/call/
call.0.wasm` (via `wasm2wat` or hexdump) to extract the
`as-call_indirect-last` shape, then either fix in JIT codegen
OR add a finer-grained skip token (e.g.
`SKIP-WIN64-CALL-INDIRECT-TRAP`) with a paired D-163 debt row.
Type: `architectural` (4th cycle in the W4 retry chain — per
architectural_spike.md, cycles 1-3 produced clear measurable
progress; this is now investigation continuation).

After W4 green: spike `private/spikes/win64-recovery-pc-sp/`
status flips `merged-into-prod`; row 10 W6 Windows DCE symbol
verification; row 11 §9.13-0 close + Phase 9 boundary.

## Critical: do NOT widen shared `Error` for Win64 gaps

`src/engine/codegen/shared/entry.zig` is auto-loaded with
[`platform_panic_vs_error.md`](../.claude/rules/platform_panic_vs_error.md).
Win64 else-branches in comptime arch conditionals MUST use
`@panic("D-NNN")`, NOT new `Error` variants. See lesson
[`2026-05-22-platform-panic-vs-error-widening.md`](./lessons/2026-05-22-platform-panic-vs-error-widening.md).

## Win64 iteration workflow (4-tier, ~150× speedup)

Inner loop = Mac cross-compile
(`zig build -Dtarget=x86_64-windows-gnu`, ~3s). L1 sync via
`tar cf - src/ test/ build.zig | ssh windowsmini "cd ... && tar xf -"`
(~4s; rsync not on windowsmini). L3 (commit + push + test-all)
**only at chunk close**, not per iteration. Per close-plan §0.2.1.

## windowsmini state

- 9 tools + sysinternals installed via
  `scripts/windows/install_tools.ps1` (`711bdcce`).
- Defender exclusion baseline configured 2026-05-22.
- Surveys: `private/notes/p9-9.13-0-survey.md` (W0),
  `private/notes/p9-d028-flake-rate.md` (W1 partial),
  `private/notes/p9-9.13-0-w3a-survey.md` (W3.a).

## Active `now` debts

(none. D-136 in-flight discharge across W3.b; row stays
`blocked-by: <Win64 SEH bridge land + W4 reconcile>` until
W4 confirms windowsmini green.)

## Open questions / blockers

D-028 next probe defers to post-W3.b natural-experiment
(streak rule N=5 silent test-all runs). The N=1 confirmation
at `ba68a896` (Defender real-time scan hypothesis) is one
data point.

## See

- Execution plan: [`phase9_13_0_close_plan.md`](./phase9_13_0_close_plan.md).
- ROADMAP §9.13-0 / §9.12-F / §9.12-I.
- ADR 0102: [`decisions/0102_phase9_debt_exit_reframe.md`](./decisions/0102_phase9_debt_exit_reframe.md).
- ADR 0103: [`decisions/0103_win64_seh_bridge.md`](./decisions/0103_win64_seh_bridge.md).
- [`debt.md`](./debt.md): D-028 / D-136 (active Cat IV).
