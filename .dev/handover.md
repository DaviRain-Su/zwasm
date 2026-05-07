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

直近 commit (HEAD = `68dd2dc`):

- `68dd2dc` feat(p7): §9.7 / 7.10 chunk d — x86_64 op_alu_float parallel-move (D-029 FP mirror)
- `4fb4fcb` feat(p7): §9.7 / 7.10 chunk c — x86_64 op_call i64 marshal + capture widening
- `a8777ac` feat(p7): §9.7 / 7.10 chunk b — x86_64 parallel-move ALU (D-029 discharge)
- `9e1978a` feat(p7): §9.7 / 7.9 chunk d-14 — arm64 op_memory 32-bit offset MOVZ/MOVK lowering

**Phase status**: §9.7 / 7.5 + 7.8 + **7.9 [x]**。Phase 7 残 row = 7.10 /
7.11 🔒 / 7.12 / 7.13 🔒。

**§9.7 / 7.10 progress** (Linux x86_64 realworld_run_jit 0/55 still):
- 7.10-a baseline: 0/55 compile-pass、52 COMPILE-OP の内訳 (D-029 33、
  total_locals>15 11、op_call:242 5、他)。
- 7.10-b (`a8777ac`): D-029 i32/i64 binary + shift parallel-move
  (commute / R10 scratch)。33+8+8+8 reject 解消。
- 7.10-c (`4fb4fcb`): op_call i64 marshal + capture (.q-form MOV)。
  14+7 → 1+1 (f32/f64 leftover)。
- 7.10-d (`68dd2dc`): op_alu_float f32/f64 binary parallel-move
  (XMM14 scratch for sub/div)。16 reject 解消。

各 chunk は dominant bottleneck を解消するが、各 fixture は複数
gap を chain しているため compile-pass 数自体は 0/55 のまま。
7.10 全体としては bottleneck の枯渇=infra 完備が exit と判断。

**§9.7 / 7.10 chain plan** (NEXT 群):
- **7.10-e (NEXT)**: op_call.marshalCallArgs f32/f64 (XMM レジスタ
  → arg_xmms) + captureCallResult f32/f64。chunk c の FP 版。
- 7.10-f: op_call:217 caller-side stack-args (arm64 d-11 mirror、
  outgoing_max region + 5+ args)。
- 7.10-g: total_locals>15 cap 拡張 — `localDisp` を i8→i32 disp に
  広げる encoding 大規模 refactor。MOV/STR 系の disp32 form
  encoder を追加し、localBaseOff 経由化と組み合わせる。chunk
  サイズが 400 LOC を超えるので 7.10-g1/g2 に分割可能。
- 7.10-h: op_control:178 / :104 / :78 — `depth == labels.len`
  (function-return) 経路を追加。x86_64 op_control.zig は
  positional API; signature 拡張 (func/frame_bytes/uses_runtime_ptr
  受け取り) または return_fixups 機構導入 (arm64 mirror)。
- 7.10-i: spill-aware op_call.captureCallResult (arm64 d-13 mirror)。
- 7.10-j: op_memory 32-bit offset (arm64 d-14 mirror)。

**Pre-existing infra observation (out-of-scope)**:
`.githooks/pre_commit` (snake_case) は Git の `pre-commit`
(kebab-case) hook 規約に合わないため fire しない。よって
gate_commit.sh の `zig fmt --check src/` (38 files drift
中、主に `@"opname"` → bare name の Zig 0.16 fmt rule 由来)
+ `file_size_check --gate` (3 files が hard-cap 2000 超過、
全 pre-existing) も実行されていない。直近 10+ commit すべて
この状態で land 済 → 既存 infra bug。修復は専用 chore commit
で別途 (gate を有効化するなら大規模 fmt 適用 + ファイル分割
ADR が必要)。

**Pre-existing infra observation (out-of-scope)**:
`.githooks/pre_commit` (snake_case) は Git の `pre-commit`
(kebab-case) hook 規約に合わないため fire しない。よって
gate_commit.sh の `zig fmt --check src/` (38 files drift
中、主に `@"opname"` → bare name の Zig 0.16 fmt rule 由来)
+ `file_size_check --gate` (3 files が hard-cap 2000 超過、
全 pre-existing) も実行されていない。直近 10+ commit すべて
この状態で land 済 → 既存 infra bug。修復は専用 chore commit
で別途 (gate を有効化するなら大規模 fmt 適用 + ファイル分割
ADR が必要)。

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
- **D-029** x86_64 emitI32Binary `dst==rhs` reject — regalloc port 後に discharge。
- **D-031** discharged (chunk d-3, `71f3896`) — runI32Export now
  allocates real memory + populates data segments; `at_limit_load_i32`
  境界 fixture 再追加は post-d-4 (FP/i64 拡張で arg marshaling 追加後)。
- **D-045** §9.7 / 7.8 close blocker — discharged (chunks 1-14e)。
- **D-046** memory.copy/fill — discharged (chunk c2, `ca01778`)。
- **D-047** div_s INT_MIN/-1 overflow trap — discharged (chunk c3, `ceb5b1e`)。
- 詳細・staleness check は `.dev/debt.md`。

## Recently closed (canonical history via `git log --oneline --grep="§9.7"`)

- §9.7 / 7.9 [x] — arm64 realworld JIT 52/55 compile-pass; chunks
  d-11..d-14 で caller-side stack-arg, spill-aware capture, 32-bit
  offset lowering を完備 (commits `f532e16` `e0212ec` `659b01e`
  `9e1978a`)。
- §9.7 / 7.8 [x] (`9a48b3a`): x86_64 JIT spec gate 3-host green
  (212/0/20 each)。D-045 closed across chunks 1-14e。
