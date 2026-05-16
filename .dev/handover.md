# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **d-73 closed: debt cleanup (24 stale `discharged-by:` rows pruned)**

### One-line state

d-73 prunes 24 stale `discharged-by:` rows from the
Active section of `.dev/debt.md` per Step 0.5 "when
discharged, delete the row". Removed: D-101 / D-107 /
D-108 / D-109 / D-110 / D-111 / D-112 / D-113 / D-114 /
D-115 / D-116 / D-118 / D-119 / D-120 / D-121 / D-122 /
D-123 / D-124 / D-125 / D-127 / D-128 / D-129 / D-130
(+1 straggler). Active D-rows 52 → 28. Recently-
discharged section untouched. `zig build` rc=0.
D-72's D-134 instrumentation remains in place awaiting
the next failing OrbStack run.

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

### Next sub-chunk candidates (d-73+)

- **D-134 awaits next failure**: d-72 instrumentation is
  in place; the autonomous loop should pivot to other
  work and let D-134 surface evidence on its own
  schedule. The remaining unprobed hypothesis (iii-b)
  (signal mask blocks SIGSEGV at delivery) needs a
  failing run to verify; doing more proactive probes
  before the flake fires is wheel-spinning.
- **D-133 remaining sites** — still queued for substrate
  audit unified comptime-disjointness mechanism (Q5).
- **D-095 partial / D-126 / D-133** are all substrate-
  audit-scope or Phase 10+ scope; no autonomous-loop
  progress without ADR / gate clearance.
- §9.9 closure via "active corpora green" interpretation
  requires ADR per §18.2 (skip-impl ≠ 0 vs ADR-0029 Path
  B exit text); not autonomous-loop scope.

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
