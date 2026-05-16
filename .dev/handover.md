# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **d-70 closed: debt cleanup (D-093 + D-097 + D-099 deleted)**

### One-line state

d-70 prunes 3 stale debt rows per `/continue` Step 0.5
discipline. **D-093** (`wasm-2.0 spec corpus failures
surfaced by k-1-expand-2 bisection`): all 4 named bug
clusters (a-d) discharged through d-1..d-69. **D-097** had
`discharged-by: ADR-0060 d-18` (stale). **D-099** had
`discharged-by: d-24` (stale). D-095 narrative tweaked.
Doc-only; `zig build` rc=0. Handover trimmed (was 272
lines, well past the 80-line cap; stale prose deleted —
all preserved in git log / phase_log).

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

### Next sub-chunk candidates (d-71+)

- **D-134 deeper investigation**: enumerate non-stdlib
  sigaction(.SEGV) callers reachable from the runner
  (DebugAllocator diagnostic / panic paths). Per
  `.claude/rules/extended_challenge.md` Step 4: WebFetch
  Zig issue tracker for "SEGV handler reinstall during
  Debug builds" + "DebugAllocator double-free SEGV".
- **D-133 remaining sites** — still queued for substrate
  audit unified comptime-disjointness mechanism (Q5).
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
