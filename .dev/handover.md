# Session handover

> ≤ 100 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure (FOLLOW THIS ORDER)

1. **READ FIRST**:
   [`.dev/phase9_close_plan.md`](phase9_close_plan.md) §6 work
   sequence. Step (a) amendment cycle **landed** in this session;
   the current active task is **Step (b) — Cat II multi-result
   entry helpers**.
2. `git log --oneline -15` — most recent commit is the step (a)
   bundle (ROADMAP §9.9 4-category rescope + ADR-0065 + ADR-0056
   amend + debt re-eval + substrate audit Q5 extension).
3. `bash scripts/p9_simd_status.sh` — live SIMD FAIL/SKIP.
4. `cat .dev/debt.md | head -90` — `now` + `blocked-by:`. Note
   **D-079 flipped to `now` 2026-05-17** (barrier dissolved per
   ADR-0065 Cat III absorption); D-105 / D-102 / D-103 barrier
   text updated to point at §9.9-III; D-126 / D-136 body cite
   ADR-0065.
5. ROADMAP §9 task table — `[ ]` on 9.9 (umbrella) + 9.9-II +
   9.9-III + 9.9-IV (4-category discharge rows; new this session).

## Active state — **Phase 9 close-plan Step (b) — Cat II**

### One-line state

Step (b) Cat II in progress: (b)-1..(b)-3 landed cumulative +24
PASS (24001→24025). (b)-3 narrowed D-137: same-width 2× int
solved via u64-padded `FuncRet_*` layout. ARM64 `br_table`→
function-depth multi-result marshal bug fixed inline (was
hand-rolling single-result marshal; now delegates to
`marshalFunctionReturn`). D-137 residual = mixed int+float
multi-result only.

**Current spec_assert tally** (Mac aarch64 + OrbStack
bit-identical post-(b)-3; live via
`bash scripts/p9_simd_status.sh`):

- spec_assert non-simd: **24025 / 0 / 2045** (+24 PASS / -24
  skip-impl vs 2026-05-17 baseline 24001/0/2069)
- simd_assert: **13301 / 0 / 440** (unchanged)

### Next-session active task

**Chunk (b)-4 — D-137 residual: mixed int+float multi-result**.
~12 remaining FAIL/skip lines for shapes like `()→(i32, f64)`,
`()→(f64, i32)` (spec `type-all-i32-f64`, `value-i32-f64`,
`return-i32-f64`, `break-i32-f64`). Discharge via either:

- (a) JIT-side: extend epilogue to route FP results via C-ABI
  HFA / mixed-class register layout for entry-helper-bound
  functions.
- (b) Zig-side: inline-asm thunk capturing result[0] from X0/RAX
  and result[1] from V0/XMM0 into a Zig-owned struct.

ADR-grade design; file `.dev/decisions/0066_*.md`. After (b)-4,
remaining shapes are 3-result (`(i32, i32, i32)`,
`(i32, i32, i64)`) which need indirect-result-pointer ABI
(C-ABI returns 24+ byte struct via X8 pointer on AAPCS64).

### Discipline reminders

- Pre-commit hook active (`.githooks/pre-commit` →
  `scripts/gate_commit.sh`). **No `--no-verify`** per ROADMAP
  §14. `core.hooksPath` auto-set by `flake.nix` shellHook.
- `.claude/rules/heisenbug_discharge.md` — D-134 streak counter
  at `private/heisenbug-d134.log`; record per OrbStack run via
  `bash scripts/track_heisenbug.sh d134 silent|segv`.
- `.claude/skills/audit_scaffolding/CHECKS.md` §F.3a / §G.3 /
  §G.4 — new lints; invoke at phase boundary.
- TODO(D-136) markers in `test/spec/spec_assert_runner_base.zig`
  flag Windows-compat stubs as workarounds; SEH bridge work
  discharges them in Step (d).
- **Substrate audit Q5 / Q4 carry Cat III hygiene anchors** —
  `src/runtime/instance/` and c_api cross-module code written
  during Cat III must follow `no_copy_from_v1.md` +
  `single_slot_dual_meaning.md` + invariant-comment lint
  discipline; the audit retroactively applies its enforcement
  strategy to that layer at 9.12 close.

### Outstanding `now` debts (post-2026-05-17 step (a) cycle)

- **D-052** (now): x86_64 prologue.zig extract; barrier
  dissolved 2026-05-17. D-081 follows.
- **D-079** (now, newly flipped): v128 cross-module imports
  (sub-gap ii); rides §9.9-III Cat III work.
- **D-126** (now): bulk.wast call_indirect post-table-mutation;
  Phase 9 §9.9-III scope per ADR-0065.
- **D-133** (now): arm64 op_table / op_memory hardcoded scratch;
  substrate audit Q5 anchor.
- **D-134** (now): OrbStack heisenbug; streak counter armed.
- **D-135** (blocked-by entry.zig cap / new ABI variant): ADR-0063
  Alt B comptime entry helper generation.
- **D-136** (blocked-by Win64 SEH bridge): assert_trap recovery
  on Windows. Cat IV scope; discharged at Step (d).

## Sandbox quirks + hook scope

- `~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- OrbStack daemon log-rotation panic — restart via
  `pkill -9 -f OrbStack && open -a OrbStack`.
- Per-chunk 2-host (Mac+OrbStack) per ADR-0049; windowsmini
  reconcile is **Step (d) batch**, not per-chunk.
- Pre-commit hook failures must be fixed at root, not bypassed.

## Reference chain

- **PRIMARY**: [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
  — the authoritative plan; this handover is the pointer
- [`.dev/decisions/0065_wasm_1_0_instance_work_phase9_rescope.md`](decisions/0065_wasm_1_0_instance_work_phase9_rescope.md)
  — Cat III Phase 9 absorption (new this session)
- [`.dev/decisions/0056_phase9_scope_extension_to_wasm2_full.md`](decisions/0056_phase9_scope_extension_to_wasm2_full.md)
  — 4-category exit predicate amend (2026-05-17 Revision row)
- [`.dev/decisions/0062_phase9_substrate_audit_gate.md`](decisions/0062_phase9_substrate_audit_gate.md)
  — substrate audit gate at 9.12 (post-Phase-9 close)
- [`.dev/phase9_completion_substrate_audit.md`](phase9_completion_substrate_audit.md)
  — 9.12 hard gate doc (Q4/Q5 extended for Cat III parallelism)
- [`.dev/phase_log/phase9.md`](phase_log/phase9.md) — per-chunk
  historical record (d-1..d-85 complete)
- [`.dev/lessons/2026-05-16-narrative-claim-vs-landed-state.md`](lessons/2026-05-16-narrative-claim-vs-landed-state.md)
  — discipline anchor for "claim ≠ landed state"
