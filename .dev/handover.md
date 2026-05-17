# Session handover

> ≤ 100 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure (FOLLOW THIS ORDER)

1. **READ FIRST**:
   [`.dev/phase9_close_plan.md`](phase9_close_plan.md) §6 work
   sequence. Step (c) Cat III dispatch in progress; (c)-1/(c)-2.0/
   (c)-2.1 landed in earlier commits.
2. `git log --oneline -15` — the 2026-05-17 consolidation
   commit lands **D-134 closed (ADR-0067 ubuntunote pivot)** +
   project-wide host references updated.
3. `bash scripts/p9_simd_status.sh` — live status via ubuntunote
   per ADR-0067.
4. `cat .dev/debt.md | head -90` — `now` + `blocked-by:`.
5. ROADMAP §9 task table — Cat III sub-chunks tracked in
   close-plan §6 step (c), not granular ROADMAP rows.

## Active state — **Phase 9 close-plan Step (c)-2 — Cat III dispatch**

### One-line state

**D-134 closed 2026-05-17 by ADR-0067**: root cause was Apple
Rosetta 2 signal-translation race on OrbStack `my-ubuntu-amd64`;
per-chunk Linux x86_64 gate host pivoted to native
`ubuntunote.local` (Ubuntu 24.04 LTS, 8c / 31GB, NOPASSWD sudo,
Determinate Nix, direnv+nix-direnv pinned via `flake.nix`).
Bit-identical 24034/0/2015 + 13301/0/440 with Mac aarch64;
5/5 deterministic-green on `test-spec-wasm-2.0-assert`. Cat III
progress unchanged by this commit: (c)-1a/b/c registry
foundation done; (c)-2.0 ADR-0066 design; (c)-2.1 thunk encoders
landed. **(c)-2.2 thunk arena lifecycle is WIP locally**
(`src/engine/codegen/shared/thunk.zig` `allocArena` / etc.
written + Mac+ubuntunote test gate green, but NOT committed in
this Ubuntu pivot commit — pending post-pivot review pass).

### Next-session active task

**Either (a) review + commit (c)-2.2 thunk arena (WIP in
working tree), then (b) Step (c)-2.3 resolver wire-up** per
ADR-0066 §Consequences / Implementation chunk plan.

(c)-2.3 walks the importer's import section; for each func
import where `Store.lookup(import.module)` finds a registered
exporter, finds the named export's JIT entry, emits a bridge
thunk into the per-instance arena via
`shared.thunk.emitThunk` + `thunkSlot`, plants
`@intFromPtr(&thunk_slot)` into `host_dispatch_base[idx]`.
Imports without a registered exporter keep the existing
`hostImportTrapStub` / `hostDispatchTrap` pointer.

Open questions for (c)-2.3:
- Arena lifetime owner — extend `JitModule` with an optional
  `thunk_block` field, or attach to the `setupRuntime` return
  struct alongside `dispatch`?
- Resolver finding the named export's JIT entry —
  `Instance.exports` indexing into `JitModule.func_offsets`
  (confirm `*anyopaque`-erased Instance cast given D-139's
  spec-runner-bypass caveat).

Subsequent: (c)-2.4 spec_assert cross-module integration
fixture (discharges D-138; incidentally covers D-079 sub-gap
ii v128 cross-module imports).

### Discipline reminders

- Pre-commit hook active (`.githooks/pre-commit` →
  `scripts/gate_commit.sh`). **No `--no-verify`** per ROADMAP
  §14. `core.hooksPath` auto-set by `flake.nix` shellHook.
- 2-host gate per chunk: Mac (foreground) +
  `bash scripts/run_remote_ubuntu.sh test-all > /tmp/ubuntu.log 2>&1`
  (background) per ADR-0049 + ADR-0067. OrbStack retired from
  gate; retained as Mac-local scratch only.
- `.claude/rules/heisenbug_discharge.md` — D-134 closed
  structurally (not via streak). Future heisenbugs use the
  5-streak + 3-SHA-diversity rule.
- TODO(D-136) markers in `test/spec/spec_assert_runner_base.zig`
  flag Windows-compat stubs; SEH bridge discharges them at
  Cat IV (close-plan Step (d)).
- Substrate audit Q5 / Q4 carry Cat III hygiene anchors
  (`no_copy_from_v1.md` + `single_slot_dual_meaning.md` +
  invariant-comment lint) for instance-layer code.

### Outstanding `now` debts

- **D-052** (now): x86_64 prologue.zig extract.
- **D-079** (now): v128 cross-module imports sub-gap ii;
  rides §9.9-III work.
- **D-126** (now): bulk.wast call_indirect post-table-mutation;
  Phase 9 §9.9-III scope per ADR-0065.
- **D-133** (now): arm64 op_table / op_memory hardcoded
  scratch; substrate audit Q5 anchor.
- **D-135** (blocked-by entry.zig cap / new ABI variant):
  ADR-0063 Alt B comptime entry helper generation.
- **D-136** (blocked-by Win64 SEH bridge): assert_trap recovery
  on Windows. Cat IV scope.
- **D-138** (blocked-by per-import bound dispatch): cross-
  module no-op stub hang. Discharged at (c)-2.4 landing.
- **D-141** (blocked-by substrate audit Q3): file_size_check
  WARN proliferation.

## Sandbox quirks + hook scope

- `~/.cache/zig` → `ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache`.
- Per-chunk 2-host (Mac + ubuntunote) per ADR-0049 + ADR-0067;
  windowsmini reconcile is Phase-boundary batch.
- Pre-commit hook failures must be fixed at root, not bypassed.

## Reference chain

- **PRIMARY**: [`.dev/phase9_close_plan.md`](phase9_close_plan.md)
- [`.dev/decisions/0065_wasm_1_0_instance_work_phase9_rescope.md`](decisions/0065_wasm_1_0_instance_work_phase9_rescope.md)
- [`.dev/decisions/0066_cross_module_import_bridge_thunks.md`](decisions/0066_cross_module_import_bridge_thunks.md)
- [`.dev/decisions/0067_ubuntunote_native_x86_64_gate_host.md`](decisions/0067_ubuntunote_native_x86_64_gate_host.md)
  — D-134 closure + Linux x86_64 gate host pivot (this commit)
- [`.dev/ubuntunote_setup.md`](ubuntunote_setup.md) — gate host setup
- [`.dev/lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md`](lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md)
- [`.dev/phase_log/phase9.md`](phase_log/phase9.md)
