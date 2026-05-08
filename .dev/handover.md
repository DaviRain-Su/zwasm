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

## Current state — Phase 7 / §9.7 / 7.11 IN-PROGRESS

直近 commit (HEAD = `7caec5a`):

- `7caec5a` fix(p7): liveness ranges leak in compile.zig errdefer chain
- `c153918` chore(p7): close §9.7 / 7.10 chunk m + discharge D-049
- `af44173` style(p7): zig fmt cleanup post 7.10-m
- `ff1e62a` feat(p7): §9.7 / 7.10 chunk m — D-049 root cause + fix

**Phase status**: §9.7 / 7.5 + 7.8 + **7.9 [x]** + **7.10 [x]**.
Phase 7 残 row = **7.11 🔒** / 7.12 / 7.13 🔒 / 7.14。

**§9.7 / 7.10 close** (this session):
- Mac arm64: 52/55 compile-pass (47/50 effective), 0 leak.
- OrbStack Linux x86_64: 45/55 compile-pass (40/50 effective), 0 leak.
- windowsmini x86_64: 45/55 compile-pass (40/50 effective), 0 leak.
- All 3 hosts SEGV-free (D-049 element-table population fix).
- liveness ranges leak in compile.zig errdefer chain
  fixed inline (`7caec5a`).

**§9.7 / 7.11 三-way differential 🔒** (NEXT row):
The most important gate of the project (per ADR-0019 carry-
forward from Phase 8 lock). Exit criterion: `interp ==
jit_arm64 == jit_x86` 0 mismatch over the spec testsuite +
40+ realworld samples on each host.

**§9.7 / 7.11 chain plan** (NEXT 群):
- **7.11-survey (NEXT)**: Step 0 Explore subagent — survey
  current diff_runner / wast_runtime_runner / spec_runner
  shape; identify what cross-engine harness exists today and
  where the three-way comparator hooks in. Verify the existing
  realworld_diff (interp vs wasmtime) shape can extend to a
  3-way (interp / arm64 / x86_64) with shared fixtures.
- 7.11-impl (next, after survey): wire a triple-runner harness
  per the survey's findings.
- 7.11-gate: 0-mismatch verification on all 3 hosts; close 7.11.

**Pre-existing infra (out-of-scope)**: `.githooks/pre_commit`
(snake_case) が fire しないため fmt/file_size/lint gate 無効。
fmt drift 38 files, hard-cap 超過 3 files (emit_test.zig +
emit.zig + inst.zig, all pre-existing), lint warns 4 (全
pre-existing)。修復は専用 chore + 大規模 fmt + 分割 ADR 必要。

> **🔒 Phase 7 → 8 hard gate** が §9.7 / 7.13 に登録済。Detection
> は Resume Step 2 + Step 7 re-target。詳細 `phase8_transition_gate.md`。
> Active row 7.11 は gate prep window (= 7.13 - 2) 内 — Step 0.6
> awareness 必須 (§3a deferred-work DAG cross-check)。

**Phase**: Phase 7 (ARM64 + x86_64 baseline、ADR-0019)。
**Branch**: `zwasm-from-scratch`。

## Open structural debt (pointers)

- **D-022** Diagnostic M3 / trace ringbuffer — Phase 7 close 後再評価。
- **D-026** env-stub host-func wiring (cross-module dispatch)。
- **D-029** parallel-move 経路完備、reject は regalloc port 後 discharge
  (currently absent from debt.md — file row at next regalloc-port chunk).
- **WASI host wiring (Phase 8 follow-up)**: 3 hosts all show
  RUN-PASS = 0/55 under ZWASM_JIT_RUN=1 because WASI host stubs
  trap on first import. Gate the conversion to RUN-PASS via
  proc_exit + fd_write minimal wiring at §9.8 entry. Not a 7.10
  blocker — the row interpreted compile-pass per 7.9 precedent.
- 詳細・staleness check は `.dev/debt.md` (all active rows are
  `blocked-by:` after D-049 discharge — zero `now` rows).
- ADR-0025 (Zig host API) Phase B/D は post-7.8 — `0025_zig_library_surface.md`。

## Recently closed
- §9.7 / 7.10 [x] (`c153918`) + chunk m fix (`ff1e62a`) — D-049
  SEGV 解消 (call_indirect funcref table population)。Edge fixture
  `test/edge_cases/p7/call_indirect/funcref_roundtrip.{wat,wasm,expect}`。
- liveness leak fix (`7caec5a`) — compile.zig errdefer chain
  (7 leaks on Linux/Windows DebugAllocator → 0)。
- §9.7 / 7.9 [x] — arm64 realworld JIT 52/55 compile-pass。
