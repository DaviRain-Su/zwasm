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

直近 commit (HEAD = `9e1978a`):

- `9e1978a` feat(p7): §9.7 / 7.9 chunk d-14 — arm64 op_memory 32-bit offset MOVZ/MOVK lowering
- `659b01e` feat(p7): §9.7 / 7.9 chunk d-13 — arm64 spill-aware captureCallResult
- `e0212ec` feat(p7): §9.7 / 7.9 chunk d-12 — arm64 SlotOverflow root-cause diag prints
- `f532e16` feat(p7): §9.7 / 7.9 chunk d-11 — arm64 caller-side AAPCS64 stack-arg lowering

**Phase status**: §9.7 / 7.5 + 7.8 + **7.9 [x]**。Phase 7 残 row = 7.10 /
7.11 🔒 / 7.12 / 7.13 🔒。

**§9.7 / 7.9 close** (compile-pass 52/55、47/50-effective、40+ 閾値
を大幅に上回る; arm64 codegen infra a..d-14 完備; 残 3 fixture は
compile-val 段階で validator-stage、codegen 由来ではない)。

**§9.7 / 7.10 plan** (NEXT、x86_64 JIT realworld): arm64 で固めた
caller-side stack-arg + spill-aware call result + 32-bit offset
lowering を x86_64 backend に移植。
- 7.10-a: x86_64 realworld JIT runner baseline 計測 — 現在の
  Linux + Windows での compile-pass / fail 内訳を取得。
- 7.10-b 以降: 計測結果に応じて arm64 d-7..d-14 と同じ shape の
  fix を順次適用 (op_call.captureCallResult / op_memory 大 offset /
  caller-stack-args)。x86_64 emit.zig は 3575 LOC で
  既に op-handler 分割済 (D-030 close); 個々の op_call.zig /
  op_memory.zig に対応する fix を入れる pattern。

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
