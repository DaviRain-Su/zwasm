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

## Current state — Phase 8 / §9.8 / 8.3 (windowsmini bench disposition)

§9.8 / 8.0+8.1+8.2 [x]. D-051 closed via ADR-0030 (test
extraction primary; prologue deferred to D-052 per ROADMAP §P14
trigger). `src/engine/codegen/x86_64/emit.zig` 4305→1247 LOC
(under §A2 hard cap); ~3050 LOC of inline tests moved to
family-split siblings `emit_test_int.zig` + `emit_test_float.zig`
+ tiny `emit_test.zig` aggregator (mirror of arm64 ADR-0021).

Mac local `ZWASM_JIT_RUN=1` realworld_run_jit baseline (8.1
exit): **52/55 compile-pass → 15/55 RUN-PASS, 37 RUN-TRAP,
0 RUN-TIMEOUT, 0 fail-other** (was 0/55 at row entry).

直近 commits (latest at top):

- (this commit) feat(p8): §9.8 / 8.2 — D-051 close via emit_test
  family split per ADR-0030; mark 8.2 [x]; D-052 records
  deferred prologue extraction.
- `85d75b7` feat(p8): §9.8 / 8.1-b — per-fixture fork+SIGALRM
  timeout; close D-050; mark 8.1 [x].
- `4fd8b61` feat(p8): §9.8 / 8.1-a — add WASI fd_read JIT thunk
  + close 8 pre-existing lint warnings.

**Phase 8 status**: §9.8 / 8.0+8.1+8.2 [x]; 8.3 NEXT. Phase 8
残 rows = 8.3 (windowsmini bench disposition) + 8.4-8.10
(optimisation pipeline + AOT skeleton + bench delta + audit +
open §9.9).

## Active task — §9.8 / 8.3: windowsmini bench Phase 8.0 disposition **NEXT**

Per Phase 7 close finding (gate doc §5b, Mac:Win ratio 3-12x
with fib2 33min/fixture): either define a windowsmini-specific
3-5 hot-fixture subset for periodic local verification, OR wire
SSH-from-Linux-runner CI integration so windowsmini bench runs
out-of-band of the inline gate cadence. Decision-driven row;
likely sub-chunks:

| #     | Description                                              | Status   |
|-------|----------------------------------------------------------|----------|
| 8.3-a | Survey windowsmini bench fixture latencies; pick subset OR confirm SSH-from-Linux as the right model. | **NEXT** |
| 8.3-b | Implement chosen approach; document in ADR if load-bearing. | [ ]      |
| 8.3-c | Update `.dev/orbstack_setup.md` / `.dev/windows_ssh_setup.md` if procedure changes; close 8.3 [x]. | [ ]      |

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
