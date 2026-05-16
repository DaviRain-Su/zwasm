# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **d-82 closed: ref.func declared-set validation, +3 PASS**

### One-line state

d-82 drains `ref_func` 3→0: validator's opRefFunc now enforces
Wasm §3.4.7.3 / §3.4.10 declared-funcrefs set; runner builds the
set from globals' ref.func init-exprs + elements' funcidxs +
exports' func entries (NOT start, NOT function bodies). Also
threads total_funcs into validateGlobalInitExpr for the ref.func
out-of-range check (ref_func.2). Result: spec_assert 23963/0/2107
→ **23966/0/2104** (+3 PASS, 0 FAIL). Total VALIDATOR-GAP 19→16.

**Cumulative d-74 → d-82 (10 chunks)**: **+182 PASS**
(23784 → 23966).

### Skip-impl drainage roadmap (post-d-82)

Remaining VALIDATOR-GAP (16): unreached-invalid 14
(deferred — polymorphic stack refactor), elem 1,
call_indirect 1.

- **d-83** — elem / call_indirect residuals (2): needs
  funcidx-out-of-range check in elem.funcidxs or
  deeper per-element init-expr decode.
- **deferred** — `unreached-invalid` (14): polymorphic
  stack refactor.

PARSER-GAP (19): binary 8, binary-leb128 7, custom 4 —
needs LEB128 over-long encoding rejection. Tractable but
spec-text-sensitive.

## Outstanding (now-resumed) `now` debts

- **D-134** OrbStack flake — instrumented at d-72;
  awaits next failure to surface (iii-b) signal-mask
  evidence. Continued proactive probing is wheel-
  spinning until then.
- **D-095** partial / **D-126** Phase 10+ / **D-133**
  substrate audit Q5 — gated.

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

### Closing path (post-d-74 user redirect)

User has redirected the loop to drain solvable
skip-impl. The next chunks (d-75+) target the remaining
SKIP-VALIDATOR-GAP / SKIP-PARSER-GAP families per the
roadmap above. Once skip-impl reaches its structural
floor (multi-result Phase 11+ scope + SKIP-CROSS-MODULE-
IMPORTS Phase 10+ scope), the §9.9 exit-criterion
interpretation question can be revisited collaboratively.

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
