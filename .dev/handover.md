# Session handover

> ≤ 80 lines. No numeric predictions
> ([`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).
> Framing discipline:
> [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Cold-start procedure — §9.13-0 close-plan override active

**Authoritative work source**:
[`.dev/phase9_13_0_close_plan.md`](./phase9_13_0_close_plan.md).
The `/continue` skill's Step 1a close-plan override
activates; follow that doc's §6 Work sequence. HEAD
`2b8e6904` (2026-05-22, D-161 close); §0 preflight is a
10-canary check (8 build tools + handle64 / Procmon64 —
full Sysinternals bundle at `711bdcce`).

## Bucket-3 stop — user touchpoint required

Per `/continue` SKILL.md stop bucket 3: all autonomous-eligible
close-plan §6 rows landed (W0 / WA / F1 / W1 / W3.a / W5 /
W6-Mac / D-161; W2 + W5 struck); zero `now` debts; no
`blocked-by:` barrier dissolved. Loop stops without
`ScheduleWakeup` re-arm.

**Gating user touchpoint(s)**:

- ADR 0103 (`.dev/decisions/0103_win64_seh_bridge.md`) —
  `Status: Proposed → Accepted` flip. After flip, autonomous
  loop resumes at **W3.b** (`src/platform/windows_traphandler.zig`
  Zone 0: `install`/`uninstall`/`arm`/`disarm` + `vehHandler`;
  wire `installSigsegvHandler` Windows arm).
- ADR 0102 (`.dev/decisions/0102_phase9_debt_exit_reframe.md`)
  — `Status: Proposed → Accepted` flip. Gates §9.13-0 close +
  Phase 9 boundary (after W4 windowsmini reconcile, itself
  gated on W3.b landing).

**Autonomous prep paths NOT YET walked** (available
next-cycle work per SKILL.md "Autonomous prep paths"):

- ADR 0103 — wasmtime traphandlers reference-repo enrichment,
  `private/spikes/win64-seh-veh/` validation spike, Consequences
  refinement.
- ADR 0102 — re-walk `.dev/debt.md` against the ADR's exit
  predicate (a/b/c clauses).

**To resume**: flip the named ADR(s) and re-invoke `/continue`.
Next cycle walks prep paths or enters W3.b impl directly.

D-028 hypothesis #5 (Defender real-time scan) **CONFIRMED**
at `ba68a896`: post-fix test-all completed without wedge.
N=1; need N=5 consecutive silent runs per
`heisenbug_discharge.md` streak rule to close. D-161 close
unblocks one more test-all data point per natural-cycle
windowsmini reconciles after W3.b lands.

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

- 9 tools (zig 0.16 / hyperfine / wasm-tools / wasmtime / wabt /
  yq / lldb / **sysinternals** [`711bdcce`]) installed via
  `scripts/windows/install_tools.ps1`.
- Defender exclusion baseline configured 2026-05-22: 8
  ExclusionPath (LLVM + sysinternals + CrashDumps + repo +
  caches) + 17 ExclusionProcess (all `addExecutable` outputs).
- `zig build test-all`: 37/39 steps OK; only spec_wasm_2_0
  runtime fails (D-136 SEH crashes inside).
- **Debug wiring** (per b737d53e): `debug_jit_auto` skill
  Recipes 9-14 + `windows_ssh_setup.md` "Interactive JIT debug
  session" section now provide windowsmini-equivalent
  "actively wired" debug posture (lldb-via-SSH, Procmon, fd
  count via handle64, llvm-objdump PE, WER post-mortem).
  Real-cycle試運転 deferred to W3.b implementation phase.
- Surveys: `private/notes/p9-9.13-0-survey.md` (W0),
  `private/notes/p9-d028-flake-rate.md` (W1 partial),
  `private/notes/p9-9.13-0-w3a-survey.md` (W3.a).

## Active `now` debts

(none — D-161 closed at `2b8e6904`.)

## Open questions / blockers

User touchpoints listed in Bucket-3 stop section above.
D-028 next probe defers to post-W3.b natural-experiment.

## See

- Execution plan: [`phase9_13_0_close_plan.md`](./phase9_13_0_close_plan.md).
- ROADMAP §9.13-0 / §9.12-F / §9.12-I.
- ADR 0102: [`decisions/0102_phase9_debt_exit_reframe.md`](./decisions/0102_phase9_debt_exit_reframe.md).
- ADR 0103: [`decisions/0103_win64_seh_bridge.md`](./decisions/0103_win64_seh_bridge.md).
- [`debt.md`](./debt.md): D-028 / D-136 (active Cat IV).
