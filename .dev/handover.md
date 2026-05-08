# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/phase8_transition_gate.md` — 🔒 Phase 7→8 hard gate (load-bearing).
3. `.dev/decisions/0019_x86_64_in_phase7.md` / 0021 / 0023 / 0025 / 0026 / 0027 / 0028 — recent ADRs.
4. `.dev/debt.md` — discharge `Status: now` rows; review `blocked-by` triggers.
5. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
6. `.dev/optimisation_log.md` — F-NNN / R-NNN / O-NNN ledger.

## Current state — Phase 7 / §9.7 / 7.12 IN-PROGRESS

直近 commit (HEAD pending — chunk-7.11-close):

- (pending) chore(p7): mark §9.7 / 7.11 [x] (three-way diff — cross-host
  total anchors); retarget at 7.12 (Phase-7 audit_scaffolding boundary)
- `fa23eb5` chore(p7): mark §9.7 / 7.10 [x]
- `7caec5a` fix(p7): liveness ranges leak in compile.zig errdefer chain
- `ff1e62a` feat(p7): §9.7 / 7.10 chunk m — D-049 root cause + fix

**Phase status**: §9.7 / 7.5 + 7.8 + **7.9 [x]** + **7.10 [x]** +
**7.11 [x]**. Phase 7 残 row = 7.12 (audit) / 7.13 🔒 (hard gate) / 7.14。

**§9.7 / 7.11 close** (this session):
- `scripts/check_three_host_diff.sh` aggregates cross-host total
  anchors from /tmp/{mac,orb,win}.log; verifies engine differential
  via runner-totals identity:
  - spec_assert_runner: 212/0/20 IDENTICAL all 3 hosts
  - wast_runner: 1158/0 IDENTICAL all 3 hosts
  - realworld_run_runner: 44/55 passed IDENTICAL all 3 hosts
  - diff_runner: 39/55 matched IDENTICAL all 3 hosts
  - realworld_run_jit_runner: 45/55 IDENTICAL on x86_64 hosts
- Per-host interp-vs-JIT execution differential deferred to Phase 8
  alongside JIT WASI host wiring (new D-050).

**§9.7 / 7.12 (NEXT)**:
"Phase-7 boundary `audit_scaffolding` pass (auto-fired by /continue
at boundary)". Invoke audit_scaffolding skill on the closing phase;
review §A〜§G categories; address any `block` findings inline or
via debt entries; close 7.12 with the audit report path.

**§9.7 / 7.13 🔒 hard gate** is right after 7.12. The autonomous
loop must surface to the user with `phase8_transition_gate.md`
when 7.12 closes (Detection rule: row body contains 🔒 AND
phase8_transition_gate.md reference).

**Pre-existing infra (out-of-scope)**: `.githooks/pre_commit`
(snake_case) が fire しないため fmt/file_size/lint gate 無効。
fmt drift / hard-cap 超過 3 files / lint warns 4 (全 pre-existing)。

**Phase**: Phase 7 (ARM64 + x86_64 baseline、ADR-0019)。
**Branch**: `zwasm-from-scratch`。

## Open structural debt (pointers)

- **D-050 (NEW)** WASI host wiring for JIT path — gates a sharper
  7.11 per-fixture comparator + converts RUN-TRAP cluster to
  RUN-PASS for proc_exit-only fixtures. Phase 8 candidate.
- **D-022** Diagnostic M3 / trace ringbuffer — Phase 7 close 後再評価。
- **D-026** env-stub host-func wiring (cross-module dispatch)。
- **D-029** parallel-move 経路完備、reject は regalloc port 後 discharge
  (currently absent from debt.md — file row at next regalloc-port chunk).
- 詳細・staleness check は `.dev/debt.md` (no `now` rows).
- ADR-0025 (Zig host API) Phase B/D は post-7.8 — `0025_zig_library_surface.md`。

## Recently closed
- §9.7 / 7.11 [x] (this commit) — three-way differential via
  cross-host total anchors + `scripts/check_three_host_diff.sh`.
- §9.7 / 7.10 [x] (`fa23eb5`) + chunk m fix (`ff1e62a`) — D-049
  SEGV 解消。
- liveness leak fix (`7caec5a`) — compile.zig errdefer chain。
- §9.7 / 7.9 [x] — arm64 realworld JIT 52/55 compile-pass。
