# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10`.
2. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
3. `cat .dev/debt.md | head -60` — `now` + `blocked-by:`.
4. ROADMAP §9 Phase Status widget + §9.9 row text (ADR-0056).

## Active state — **d-71 closed: D-134 disambiguation — our handler does NOT fire**

### One-line state

d-71 changes `sigsegvHandler`'s unarmed-SEGV `_exit`
from 139 → 142 to disambiguate "handler fired" from
"kernel-delivered raw SIGSEGV" in zig build's failure
report. OrbStack `test-all` reproduced D-134 SEGV and
reported `signal SEGV` — NOT `exit code 142`. **Our
handler is not running for the real D-134 SEGV.** With
Zig's startup handler already disabled (d-68) and no
other stdlib `sigaction(.SEGV)` callers, the remaining
hypothesis space narrows to: (iii-a) `sigaltstack`
silently fails → SA.ONSTACK has no stack → kernel
falls back to SIG_DFL; (iii-b) signal mask blocks
SIGSEGV at delivery; (iii-c) handler replaced by some
unenumerated path between install and SEGV. Mac
aarch64 unaffected (23784/0/2286 unchanged).

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

### Next sub-chunk candidates (d-72+)

- **D-134 / hypothesis (iii-a)**: replace
  `installSigsegvHandler`'s `std.posix.sigaltstack(...)
  catch {}` swallow with explicit error reporting
  (raw-write errno to stderr OR @panic with diagnostic).
  If sigaltstack is silently failing on OrbStack Linux
  x86_64, the probe surfaces it — and the fix is then
  either fall back to no-altstack (works for non-stack-
  overflow SEGVs) or fix the altstack-size / alignment
  issue.
- **D-134 / hypothesis (iii-b/c)**: after (iii-a) is
  ruled out, probe signal-mask at signal-delivery
  context (raw sigprocmask readback at sigsetjmp arm)
  and verify our handler is still installed at runCorpus
  entry (re-readback via `sigaction(SEGV, null, &oact)`).
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
