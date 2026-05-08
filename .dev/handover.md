# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.8 task table — Phase 8 active.
3. `.dev/debt.md` — discharge `Status: now` rows; review `blocked-by` triggers.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/optimisation_log.md` — F-NNN / R-NNN / O-NNN ledger (Phase 8 candidate landings).
6. `.dev/decisions/0019_x86_64_in_phase7.md` / 0021 / 0023 / 0026 / 0027 / 0028 / 0029 — recent ADRs.
7. `.dev/phase8_transition_gate.md` — historical reference (gate now closed; 7.13 [x]).

## Current state — Phase 8 / §9.8 / 8.1 (D-050 WASI subset for JIT)

Phase 7 closed; Phase 8 open. ROADMAP §9 Phase Status widget shows
7=DONE, 8=IN-PROGRESS. §9.8 task table expanded inline (8.0-8.10).

直近 commits (latest at top; will be appended by Phase 7 close commit):

- (pending C6) chore(p7): mark §9.7 / 7.13 + 7.14 [x]; close
  Phase 7; expand §9.8 inline + flip Phase Status widget; SHA
  backfill for §9.7 rows 7.5/7.5d/7.5e/7.7/7.8.
- `60a4a67` chore(p7): windowsmini Phase 7 close partial baseline
  + handover/gate-doc updates.
- `e3e6668` chore(infra p7): hyperfine CI bench workflow (Phase 11
  deferral lifted).
- `8c51fcd` chore(debt p7): close D-009 + D-011 + D-017.
- `2214762` chore(p7): §9.7 / 7.13 gate-close artefacts (5/5
  sections ☑).
- `cde3405` refactor(p7): split x86_64/inst.zig (2530→1104) +
  arm64/emit_test.zig (2356→28 + 6 siblings); §3 file-size box
  discharge (modulo D-051).

**Phase 8 status**: §9.8 / 8.0 [x] (this commit's open). Phase
8 残 rows = 8.1 (D-050 WASI for JIT, NEXT) + 8.2 (D-051 emit.zig
prologue extraction) + 8.3 (windowsmini bench Phase 8.0
disposition) + 8.4-8.10 (optimisation pipeline + AOT skeleton +
bench delta + audit + open §9.9).

## Active task — §9.8 / 8.1: D-050 WASI subset for JIT path **NEXT**

Concrete sub-tasks per `.dev/debt.md` D-050 description:

1. Port a minimal WASI subset to JIT-callable shape via
   `host_dispatch_base[i]` thunks: `proc_exit` / `fd_write` /
   `fd_read` / `environ_get` / `environ_sizes_get` / `args_get` /
   `args_sizes_get` / `clock_time_get`.
2. Wire `setupRuntime` (`src/engine/runner.zig`) to install
   thunks instead of the trap stub for known WASI exports.
3. Add per-fixture timeout (subprocess fork + SIGALRM) so
   `cljw_*` / `tinygo_fib` loops don't hang the runner.

Three-way differential gate carried forward as the correctness
oracle (P12; per Phase 8 narrative + §9.7 / 7.11 lock).
Discharge target: `realworld_run_jit_runner` 0/55 RUN-PASS
→ ≥40/55 RUN-PASS for fixtures that complete via WASI exit;
matches interp side's 44/55.

## Phase 7 close summary (snapshot for cold-start context)

Phase 7 closed at HEAD `60a4a67` (this handover update lands at
C6). 5/5 transition gate sections ☑:

1. **Functional**: 3-host green; `check_three_host_diff.sh` PASS.
2. **Debt-ledger**: 11 Active rows (was 14 before second sweep);
   D-009 + D-011 + D-017 closed inline at gate review per user
   direction「もうdebtから消せるな」.
3. **Design cleanliness**: AOT/GC/EH/WASI-p2/SIMD slots reserved;
   2 of 3 file-size hard-cap files split (cde3405); D-051 covers
   `x86_64/emit.zig` Phase 8 entry-task.
4. **§3a deferred-work DAG**: D-035/D-036/D-037/D-030 all closed;
   D-029 deferral rationale recorded in gate doc §5a.
5. **Strategic review**: ROADMAP §1+§2 read-back consistent;
   `meta_audit` produced `2026-05-08-phase7-close.md`; CI bench
   pulled forward (e3e6668); host-baseline ratios anchored in
   `history.yaml` per gate doc §5b.

## Open structural debt (pointers — current; full list in `.dev/debt.md`)

- **D-050** WASI subset for JIT → §9.8 / 8.1 (NEXT; first Phase 8 task).
- **D-051** x86_64/emit.zig prologue extraction → §9.8 / 8.2 (ADR-grade).
- **D-022** ADR-0028 M3-a-2 trap event runtime write.
- **D-026** env-stub host-func wiring (cross-module dispatch).
- **D-029** parallel-move complete coverage (O-002 deferred per gate §5a).
- 詳細・全 11 Active rows は `.dev/debt.md` 参照。

**Phase**: Phase 8 (JIT optimisation foundation 🔒、ADR-0019)。
**Branch**: `zwasm-from-scratch`。
