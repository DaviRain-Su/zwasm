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

## Current state — Phase 7 / §9.7 / 7.10 IN-PROGRESS

直近 commit (HEAD = `6c523fa`):

- `6c523fa` feat(p7): §9.7 / 7.10 chunk f — x86_64 op_call caller-side stack-args
- `3423dc7` chore(debt): close D-014 + D-046 (barrier-dissolution sweep)
- `da5db53` feat(p7): §9.7 / 7.10 chunk e — x86_64 op_call f32/f64 marshal + capture
- `68dd2dc` feat(p7): §9.7 / 7.10 chunk d — x86_64 op_alu_float parallel-move (D-029 FP mirror)

**Phase status**: §9.7 / 7.5 + 7.8 + **7.9 [x]**。Phase 7 残 row = 7.10 /
7.11 🔒 / 7.12 / 7.13 🔒。

**§9.7 / 7.10 progress** (Linux x86_64 realworld_run_jit 0/55 still):
- chunks a..f closed: D-029 ALU 解消、op_call i32/i64/f32/f64
  marshal + capture 完備、FP D-029 mirror 解消、caller-side
  stack-args (arm64 d-11 mirror — SysV NSAA + Win64 shadow-aware
  shared-slot) + outgoing-args 領域 pre-allocation 完備。
- 各 chunk は dominant bottleneck を 1 つ解消するが、fixture は
  複数 gap を chain しているため compile-pass 数自体は 0/55。
  7.10 exit は bottleneck 枯渇=infra 完備で判断。

**§9.7 / 7.10 chain plan** (NEXT 群):
- **7.10-g (NEXT)**: total_locals>15 cap 拡張 — `localDisp` を
  i8→i32 disp に広げる encoding refactor。MOV/STR 系の disp32
  form encoder を追加し、localBaseOff 経由化と組み合わせる。
  chunk サイズが 400 LOC を超えるので g1/g2 に分割可能。
- 7.10-h: op_control:178 / :104 / :78 — `depth == labels.len`
  (function-return) 経路を追加。x86_64 op_control.zig は
  positional API; signature 拡張 (func/frame_bytes/uses_runtime_ptr
  受け取り) または return_fixups 機構導入 (arm64 mirror)。
- 7.10-i: op_memory 32-bit offset (arm64 d-14 mirror)。

**Pre-existing infra observation (out-of-scope)**:
`.githooks/pre_commit` (snake_case) は Git の `pre-commit`
(kebab-case) hook 規約に合わないため fire しない。よって
gate_commit.sh の `zig fmt --check src/` (38 files drift
中、主に `@"opname"` → bare name の Zig 0.16 fmt rule 由来)
+ `file_size_check --gate` (3 files が hard-cap 2000 超過、
全 pre-existing) + `zig build lint` (4 warnings: 2 exhaustive-
switch on x86_64/emit.zig param-marshal + 2 unused `abi` import
in op_convert/op_control) も実行されていない。直近 10+ commit
すべてこの状態で land 済 → 既存 infra bug。修復は専用 chore
commit で別途 (gate を有効化するなら大規模 fmt 適用 + ファイル
分割 ADR + lint warn 修正が必要)。

> **🔒 Phase 7 → 8 hard gate** が §9.7 / 7.13 に登録済。
> Autonomous /continue loop は 7.13 row を発見した時点で
> ScheduleWakeup を skip して user に surface する規律
> ([`phase8_transition_gate.md`](phase8_transition_gate.md) +
> `.claude/skills/continue/SKILL.md` §"Exception — hard
> human-in-loop transition gates")。Detection は 2 checkpoint
> (Resume Procedure Step 2 + Step 7 re-target) で発火。

**Phase**: Phase 7 (ARM64 + x86_64 baseline、ADR-0019)。
**Branch**: `zwasm-from-scratch`。

## ADR-0025 (Zig host API) implementation chain

Phase A (design + ROADMAP §10 sync) DONE。Phase B-1〜B-5 (thin
facade + TypedFunc + WasiConfig + ImportEntry + examples) +
Phase D (migration doc) は post-7.8 着手予定。詳細は
`.dev/decisions/0025_zig_library_surface.md` Revision history。

## Open structural debt (pointers)

- **D-022** Diagnostic M3 / trace ringbuffer — Phase 7 close 後再評価。
- **D-026** env-stub host-func wiring (cross-module dispatch)。
- **D-029** x86_64 emitI32Binary `dst==rhs` reject — chunks b/d で
  parallel-move 経路は完備、underlying reject 自体は regalloc port
  後に最終 discharge。
- 詳細・staleness check は `.dev/debt.md`。

## Recently closed (canonical history via `git log --oneline --grep="§9.7"`)

- §9.7 / 7.10 chunks a..f closed (commits `a8777ac` `4fb4fcb`
  `68dd2dc` `da5db53` `6c523fa`)。x86_64 JIT で D-029 ALU/FP
  parallel-move、op_call i32/i64/f32/f64 marshal+capture、
  caller-side stack-args (SysV NSAA + Win64 shadow-aware shared
  slot) を完備。realworld_run_jit compile-pass 数は 0/55 のまま
  (g/h/i chunks 待ち)。
- §9.7 / 7.9 [x] — arm64 realworld JIT 52/55 compile-pass。
