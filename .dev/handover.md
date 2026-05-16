# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **autonomous loop pause at d-73; awaiting bucket-2 collaborative input**

### One-line state

d-73 prunes 24 stale `discharged-by:` rows from active
section (52→28). Following d-65→d-73's nine-chunk arc
(2 real source fixes at d-66 + d-69; the rest probes /
investigation / bookkeeping), the autonomous loop has
genuinely converged on its limits for §9.9. The
`/continue` bucket-2 stop condition fires.

## Open questions / blockers (bucket-2; need collaborative input)

1. **D-134 OrbStack `zwasm-spec-wasm-2-0-assert` flake
   root cause unclear after investigation**. d-65 / d-67
   / d-69 partial / d-71 / d-72 probed and progressively
   narrowed hypotheses (cross-thread `siglongjmp`
   refuted; Zig startup handler refuted; sigaltstack +
   sigaction-readback both clean). Remaining unprobed:
   hypothesis (iii-b) signal-mask blocks SIGSEGV at
   delivery, which needs a failing OrbStack run to
   inspect sigprocmask state — the d-72 instrumentation
   is in place for the next surfaced failure. Continued
   proactive probing without new evidence is
   wheel-spinning.
2. **§9.9 closure needs load-bearing ADR for exit-
   criterion relaxation**. ROADMAP §9.9 row text per
   ADR-0056 specifies `ADR-0029 Path B \`skip-impl == 0\`
   enforcement real`. Current spec_assert non-simd
   reports 1790 skip-impl (~all multi-result, Phase 11+
   scope per ADR-0029 follow-up). Closing 9.9 with this
   skip-impl count requires either (a) eliminating
   skip-impl (structurally Phase 11+) or (b) relaxing
   the exit criterion via ADR per §18.2 (deviation from
   §9 phase scope/exit). Path (b) is the natural
   collaborative-review point.
3. **All other `now` debts blocked**: D-095 / D-133
   substrate audit Q5 scope; D-126 Phase 10+ scope.
   Substrate audit (hard gate at §9.9 / 9.12) is the
   natural unblock; it can't fire until 9.9 flips
   `[x]`.

### Phase 9 / §9.9 status

- spec_assert non-simd: 23784/0/2286 Mac aarch64
  (1790 skip-impl + 496 skip-adr).
- simd_assert: 13301/0/440 Mac + OrbStack
  (bit-identical).
- §9.9 row text exit criterion **not literally met**
  (skip-impl ≠ 0); needs ADR (above).

### Active `now` debts (28)

- **D-095** partial — substrate audit Q5 scope.
- **D-126** — Phase 10+ instance-aware refactor scope.
- **D-133** — substrate audit Q5 scope.
- **D-134** — instrumented heisenbug; awaits next
  failure with d-72 diagnostic in place.

### Phase 9 / §9.9 status

- spec_assert non-simd: 23784/0/2286 Mac aarch64
  (1790 skip-impl + 496 skip-adr).
- simd_assert: 13301/0/440 Mac + OrbStack (bit-identical).
- §9.9 closing path: still gated by D-134 (OrbStack
  flake; d-68 reduced rate via Zig-handler-disable but
  d-69 re-triggered via layout perturbation).
- Substrate audit hard gate at row 9.12 fires once 9.9
  flips `[x]`.

### Active `now` debts

- **D-095** (partial; substrate audit Q5 scope).
- **D-126** (bulk corpus residual — Phase 10+ scope).
- **D-133** (remaining ≥3-scratch op_table/op_memory
  sites — substrate audit Q5 scope).
- **D-134** (OrbStack `zwasm-spec-wasm-2-0-assert` flake;
  layout-sensitive + handler-install-race-sensitive;
  d-68 disabled Zig's startup SEGV handler but the
  heisenbug still reproduces at low rate).

### Resume paths (user-initiated)

When the user is ready to re-engage:

- **Path A — relax §9.9 exit criterion**: write
  `.dev/decisions/NNNN_<slug>.md` per §18.2 amending the
  `skip-impl == 0` clause to "active-corpora green AND
  all skip-impls structurally Phase 11+ multi-result OR
  documented per skip-ADR". Once that ADR lands, the
  loop can flip 9.9 `[x]` autonomously, fire the
  Windows reconciliation, and hand off to the substrate
  audit hard gate at 9.12.
- **Path B — fix D-134 root cause**: a failing OrbStack
  run with d-72 diagnostics in place is the next
  evidence-producing event. Sit on the bug; next
  surfaced failure will narrow hypothesis (iii-b)
  (signal mask) or surface a new mode.
- **Path C — pivot to substrate audit prep**: open
  `.dev/phase9_completion_substrate_audit.md` and
  pre-work Q2/Q3/Q4/Q5/Q6 sections. The audit's
  outcome should reshape D-095 / D-133 (the substrate-
  scope debts) into concrete chunks.

## Sandbox quirks + hook scope

- `~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- OrbStack daemon log-rotation panic — restart via
  `pkill -9 -f OrbStack && open -a OrbStack`.
- Per-chunk 2-host (Mac+OrbStack) per ADR-0049;
  windowsmini reconcile at §9.9 close (D-084 per
  ADR-0055).

## Reference chain

- `.dev/decisions/0057_spec_assert_runner_factoring.md`.
- `.dev/decisions/0058_table_ops_jit_design.md`.
- `.dev/decisions/0059_jit_memory_grow_callout.md`.
- `.dev/decisions/0060_regalloc_call_crossing_force_spill.md`.
- `.dev/decisions/0061_wasm_3_0_deferral_policy.md`.
- `.dev/decisions/0062_phase9_substrate_audit_gate.md`.
- `.dev/phase9_completion_substrate_audit.md` (hard gate
  9.12 document).
- `.dev/lessons/2026-05-16-narrative-claim-vs-landed-state.md`
  (d-68 / d-69 retrospective on overoptimistic
  "DISCHARGED" claims).
- `.dev/phase_log/phase9.md` (per-sub-chunk records).
