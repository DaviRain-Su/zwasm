# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **d-84 closed: PARSER-GAP full drain (19→0) + Mac/OrbStack bit-identical, +19 PASS**

### One-line state

d-84 bundles 5 spec-rule tightenings to drain all 19
SKIP-PARSER-GAP entries: (a) eager type-section decode catches
canonical-LEB issues in modules with no imports/funcs; (b)
function-vs-code count consistency for the "code without
function section" case; (c) data_count section value vs data
section count match; (d) memory.init/data.drop require
data_count section present (Validator.data_count_section_present
field); (e) table-limits flag canonical (bit 0 only); (f)
custom-section name LEB validation at parse time. Result:
spec_assert 23968/0/2102 → **23987/0/2083** (+19 PASS, 0 FAIL).
**Mac + OrbStack bit-identical** (D-134 silent this run —
first clean OrbStack since d-65).

**Cumulative d-74 → d-84 (12 chunks)**: **+203 PASS**
(23784 → 23987).

### Skip-impl drainage roadmap (post-d-84)

Both VALIDATOR-GAP (except deferred unreached-invalid 14) AND
PARSER-GAP (full drain) are now zero. The remaining skip-impl
floor is structural:

- SKIP-CROSS-MODULE-IMPORTS 136 (Phase 10+ scope; cross-module
  registry / instance plumbing not yet on the runtime side).
- SKIP-NO-LINK-TYPECHECK 4 (cross-module signature check —
  Phase 10+).
- SKIP-START-TRAP 2 + SKIP-HOST-IMPORT 2.
- deferred VALIDATOR-GAP unreached-invalid 14 (polymorphic
  stack refactor; substrate audit scope).

Next chunks pick from these structural fronts OR survey
remaining skip-impl reasons (memory_grow, simd skip-impl, etc.)
for tractable mid-difficulty targets. The §9.9 row text exit
criterion "skip-impl == 0" remains gated by the substrate
audit interpretation (ADR-0062 hard gate at 9.12).

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
