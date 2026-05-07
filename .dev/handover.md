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

直近 commit (HEAD = `a8777ac`):

- `a8777ac` feat(p7): §9.7 / 7.10 chunk b — x86_64 parallel-move ALU (D-029 discharge)
- `9e1978a` feat(p7): §9.7 / 7.9 chunk d-14 — arm64 op_memory 32-bit offset MOVZ/MOVK lowering
- `659b01e` feat(p7): §9.7 / 7.9 chunk d-13 — arm64 spill-aware captureCallResult
- `f532e16` feat(p7): §9.7 / 7.9 chunk d-11 — arm64 caller-side AAPCS64 stack-arg lowering

**Phase status**: §9.7 / 7.5 + 7.8 + **7.9 [x]**。Phase 7 残 row = 7.10 /
7.11 🔒 / 7.12 / 7.13 🔒。

**§9.7 / 7.10 progress** (Linux x86_64 baseline → 0/55 compile-pass):
- **7.10-a (baseline)**: realworld_run_jit 0/55、52 COMPILE-OP の
  内訳: 33 op_alu_int dst==rhs (D-029)、11 total_locals>15、
  5 op_call:242 (non-i32 marshal)、他。
- **7.10-b (a8777ac)**: D-029 解消。i32/i64 binary に commute
  (add/mul/and/or/xor) + R10 scratch (sub) で parallel-move; i32/i64
  shift は既存 RCX-first 順序で dst==rhs を自然に処理 (defensive
  reject 削除)。realworld 0/55 のままだが、各 fixture が次の
  bottleneck (op_call i64/f32/f64、total_locals>15、fp ops、…) に
  shift。

**§9.7 / 7.10 chain plan** (NEXT 群):
- **7.10-c (NEXT)**: op_call.marshalCallArgs i64 拡張。`MOV .q dst,
  src` で 64-bit 引数を渡す。captureCallResult i64 も同時に追加。
- 7.10-d: op_call.marshalCallArgs f32/f64 拡張 (XMM レジスタ → arg_xmms)。
- 7.10-e: total_locals>15 cap 拡張 (arm64 d-9 と同じ shape:
  frame_bytes 拡張 + max_reg_slots 引き上げ)。
- 7.10-f: op_alu_float.zig:437 reject (binary fp 系) — D-029 と同じ
  parallel-move pattern を XMM 系に展開。
- 7.10-g: caller-side stack-args (arm64 d-11 mirror)。
- 7.10-h: spill-aware op_call.captureCallResult (arm64 d-13 mirror)。
- 7.10-i: op_memory 32-bit offset (arm64 d-14 mirror)。

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
