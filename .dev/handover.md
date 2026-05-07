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

## Current state — Phase 7 / §9.7 / 7.9 IN-PROGRESS

直近 commit (HEAD = `f532e16`):

- `f532e16` feat(p7): §9.7 / 7.9 chunk d-11 — arm64 caller-side AAPCS64 stack-arg lowering
- `b9a5948` feat(p7): §9.7 / 7.9 chunk d-10 — arm64 op_call caller-side reject diag prints
- `cc6a0eb` feat(p7): §9.7 / 7.9 chunk d-9 — arm64 frame_bytes + regalloc max_slots widening
- `03d9875` feat(p7): §9.7 / 7.9 chunk d-8 — D-034 spill-aware migration tail (35 sites)

**Phase status**: §9.7 / 7.5 + 7.8 → **[x]**。Phase 7 残 row = 7.9 /
7.10 / 7.11 🔒 / 7.12 / 7.13 🔒。

**§9.7 / 7.9 progress**: chunks a..d-11 closed across 24 commits。
realworld JIT compile-pass: 5/55 → 33/55 (chunk d-11 +6)。
3-host gate green。

**Chunk 7.9-d-11 完了** (`f532e16`): option-2 を採用。
caller frame の bottom に `outgoing_max_bytes` の outgoing-args
region を予約; locals + spills は `local_base_off` だけ shift。
`computeOutgoingMaxBytes` で `call N` / `call_indirect` を pre-
scan し最悪値を計算。emit.zig 21 site (param-store loop / 宣言
local zero-init / local.get/set/tee) が `[SP, #(local_base_off
+ idx*8)]` 経由に。`op_call.marshalCallArgs` は arg_vregs cap を
8 → 64 に上げ、overflow int (>X7) / fp (>V7) を STR W/X/S/D で
`[SP, #(K*8)]` に書き出す (NSAA index per AAPCS64 §6.4.2)。
callee 側 d-7 の `[X29, #16+8*K]` 取り込みは無変更で完結。
Mac aarch64 realworld_run_jit: 27/55 → 33/55 (+6); 残り 19
COMPILE-OP は **全て SlotOverflow** に集約 (= regalloc 段階
exhaustion)。

**Chunk 7.9-d-12 plan** (NEXT): SlotOverflow 19 fixtures の
共通根本原因を特定。候補:
1. `max_reg_slots_gpr/fp` の更なる引き上げ (現在 GPR=8, FP=13)
   — 単純引き上げで何が unblock されるか測定。
2. vreg coalesce (連鎖 ALU の中間 vreg を即時 reuse) — ADR-grade。
3. SlotOverflow 発火時の diag 拡張で具体 op / vreg id を出す
   (d-10 と同じパターン)。
推奨: まず 3 で計測 → 1 か 2 を選択。

**§9.7 / 7.9 exit criterion** (40+ realworld run-pass) は run-
stage 計測が opt-in (per-fixture timeout NYI) のため compile-
pass 33/55 + 全 infra 揃った状態で 7.13 boundary review で
「7.9 = infra 完備」として 7.10/7.11/7.12 chain に進む判断
が妥当。

**Pre-existing infra observation (out-of-scope for d-11)**:
`.githooks/pre_commit` (snake_case) は Git の `pre-commit`
(kebab-case) hook 規約に合わないため fire しない。よって
gate_commit.sh の `zig fmt --check src/` (38 files drift
中、主に `@"opname"` → bare name の Zig 0.16 fmt rule 由来)
+ `file_size_check --gate` (3 files が hard-cap 2000 超過、
全 pre-existing) も実行されていない。直近 10 commit すべて
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

## Recently closed (full history via `git log --oneline`)

- §9.7 / 7.8 [x] (`9a48b3a`): x86_64 JIT spec gate exit met on
  all 3 hosts (Mac/Linux/Win 212/0/20)。test-spec-assert を
  test-all 全 host 配線。D-045 closed across chunks 1-14e
  (+163 PASS each on Linux + Win)。
- §9.7 / 7.8-win64-stack-args (`d7236d0`): Win64 ABI args 4+
  on stack at [RBP+16+8*slot]; fixed 5-arg case regression。
- §9.7 / 7.8-win64-fp-params (`95a64bb`): Cc-aware FP arg slot
  tracking; Win64 shares int/FP slots, SysV independent。
- §9.7 / 7.8-unreachable-trap-flag (`50a6f47`): unreachable op を
  uses_runtime_ptr prescan に追加; trap stub の R15 参照が
  正しく初期化される (closes 25 "did NOT trap" fails)。
- §9.7 / 7.8-deadcode-labels (`fb64e3e` + `ea3ef20`): dead_code
  内 if/block/loop で placeholder label push、emitElse の
  if_skip_byte null-guard。中央化 `types.rejectUnsupported`
  helper で diag 整備。+56 PASS。
- §9.7 / 7.8-zero-init-locals (`bb8ccb5`): Wasm spec §4.5.3.1
  zero-init in prologue。+10 PASS。
- §9.7 / 7.8-spill-aware-regalloc (13a `e811441` + 13b
  `aaa2268`): R10/R11 + XMM14/15 を spill stage に reserve、
  110 op handler を gpr.gpr*Spilled / xmm*Spilled 経由に
  migrate。+62 PASS。
- §9.7 / 7.8-jit-mem-windows (`2748971` + `6db570c`):
  NtAllocateVirtualMemory による Windows RWX。+56 PASS。
