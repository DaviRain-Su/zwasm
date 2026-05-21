# Session handover

> ≤ 80 lines. No numeric predictions
> ([`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).
> Framing discipline:
> [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Cold-start procedure — §9.13-0 + §9.12-F parallel tracks

**Authoritative work source for this session**:
[`.dev/phase9_13_0_close_plan.md`](./phase9_13_0_close_plan.md).
The `/continue` skill's Step 1a close-plan override
activates; follow that doc's §6 Work sequence. §0 preflight
(8-tool inventory) green at HEAD `4196b385` (2026-05-22).

| Next track | First action | User touchpoint |
|---|---|---|
| W2 (main) — D-084 v128 marshal | `src/engine/codegen/x86_64/op_call.zig` + sibling: locate SysV branch, mirror to Win64 hidden-RDI ABI | none |
| W1 (subagent, parallel) — D-028 IPC flake rate | RUNNING as background subagent (10× test-all) — note lands at `private/notes/p9-d028-flake-rate.md` on completion | none |
| WA (main, parallel) — §9.12-F ADR draft | ✅ Drafted at `.dev/decisions/0102_phase9_debt_exit_reframe.md` (`4196b385`, Status: Proposed) | ADR-flip Proposed → Accepted |

§9.12-E ★ DONE (Wasm 2.0 100%). §9.12-I batched at row 11
(§9.13-0 close).

## Critical: do NOT widen shared `Error` for Win64 gaps

`src/engine/codegen/shared/entry.zig` is **auto-loaded with**
[`.claude/rules/platform_panic_vs_error.md`](../.claude/rules/platform_panic_vs_error.md).
Win64 else-branches in comptime arch conditionals MUST use
`@panic("D-NNN")`, NOT new `Error` variants. Doing the
latter cascades through every Class A/C exhaustive-switch
caller. Inline INVARIANT comments at the 3 @panic sites in
entry.zig. See lesson
[`2026-05-22-platform-panic-vs-error-widening.md`](./lessons/2026-05-22-platform-panic-vs-error-widening.md).

## Win64 iteration workflow (4-tier, ~150× speedup)

Per execution plan §0.2.1. **Inner loop = Mac cross-compile**
(`zig build -Dtarget=x86_64-windows-gnu`, ~3s). L1 sync via
`tar cf - src/ test/ build.zig | ssh windowsmini "cd ... && tar xf -"`
(~4s; rsync not on windowsmini). L3 (commit + push +
test-all) **only at chunk close**, not per iteration.

## windowsmini state

- 8 tools installed via `scripts/windows/install_tools.ps1`:
  zig 0.16.0 / hyperfine / wasm-tools / wasmtime / wabt /
  yq / lldb (LLVM 22.1.6 + python311.dll).
- `zig build`: ✓ (was failing pre-wabt).
- `zig build test`: 1744/1775 pass, 2 D-136 SEH crashes.
- `zig build test-all`: 37/39 steps OK; only spec_wasm_2_0
  runtime fails (D-136 inside).
- W0 survey: `private/notes/p9-9.13-0-survey.md`.

## Current Phase 9 state

| Exit | Latest fact |
|---|---|
| §9.13-0 windowsmini full green | D-022 F1 closed (`0c2474c2`); D-084 / D-028 / D-136 open |
| §9.12-F debt active rows < 15 | 19 active; WA ADR 0102 Proposed (`4196b385`) reframes exit per-row predicate |
| §9.12-I ADR `Accepted` < 30 | strict 33; batched at Phase 9 close |

## Active `now` debts

- なし.

## Open questions / blockers

- §9.12-F exit re-framing — ADR 0102 Proposed; ADR-flip
  Proposed → Accepted needs user (allowed `user-judgment`
  per `handover_framing.md`: §18 ADR-flip review).

## Recent context (2026-05-22 commits)

- `4196b385` — ADR 0102 draft (§9.12-F exit reframe, Proposed).
- `1b4a5b5a` — README refresh (status / platforms / Wasm-WASI / CLI).
- `7f360d21` — rename execution_plan → close_plan + handover refresh.
- `411eacfb` — measured L0/L1 timings + tar-pipe workflow.
- `606bb941` — system-level defense (`platform_panic_vs_error.md` +
  inline INVARIANT + lesson) + Win64 iter workflow §0.2.1.
- `0c2474c2` — F1 fix via `@panic` (correct approach).

## See

- Execution plan: [`phase9_13_0_close_plan.md`](./phase9_13_0_close_plan.md).
- ROADMAP §9.13-0 / §9.12-F / §9.12-I.
- [`debt.md`](./debt.md): D-022 / D-028 / D-084 / D-136.
- ADR 0102: [`decisions/0102_phase9_debt_exit_reframe.md`](./decisions/0102_phase9_debt_exit_reframe.md).
