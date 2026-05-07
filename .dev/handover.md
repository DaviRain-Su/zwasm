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

直近 commit (HEAD = `<this>`):

- `<this>` chore(p7): §9.7 / 7.9 chunk d-9 close (frame_bytes + max_slots widening)
- `cc6a0eb` feat(p7): §9.7 / 7.9 chunk d-9 — arm64 frame_bytes + regalloc max_slots widening
- `03d9875` feat(p7): §9.7 / 7.9 chunk d-8 — D-034 spill-aware migration tail (35 sites)
- `57e2ef2` feat(p7): §9.7 / 7.9 chunk d-7 — arm64 callee-side AAPCS64 stack-arg lowering

**Phase status**: §9.7 / 7.5 + 7.8 → **[x]**。Phase 7 残 row = 7.9 /
7.10 / 7.11 🔒 / 7.12 / 7.13 🔒。

**§9.7 / 7.9 progress**: chunks a..d-9 closed across 21 commits。
realworld JIT compile-pass: 5/55 → 27/55 (chunk d-6 大躍進)。
3-host gate green。

**Chunk 7.9-d-9 完了** (`cc6a0eb`): arm64 frame_bytes + regalloc
max_slots widening. `arm64/inst.zig:encSubImm12Lsl12` (新)、
prologue/epilogue/trap-stub の SUB/ADD SP を 2-instr 化、
`frame_bytes` 4096 → 16 MiB-1 cap。`shared/regalloc.zig:max_slots`
1023 → 4095。compile-pass 27/55 不変 — Go fixtures は別の
barrier (op-level UnsupportedOp) が次の hit point。

**Chunk 7.9-d-10 plan** (NEXT — diagnostic investigation):
- 失敗 fixture を 1 つずつ手動 compile して特定 UnsupportedOp の
  発生 op tag を identify (debug-print 一時挿入 → 削除 cycle)。
- 多くは特定 op (table.copy / table.init / ref.func / try /
  delegate / atomic.* など Wasm 2.0/3.0 features) の未実装が
  原因の見込み。各 op の lowering / liveness / emit 追加で
  漸進 unblock。

**§9.7 / 7.9 exit criterion** (40+ realworld run-pass) は現実的
には不可能 — 大半の fixture は (a) caller-side stack-arg, (b)
specific op gaps, (c) per-fixture timeout の総合改善が必要で、
個別に対応するより Phase 7→8 boundary review (7.13) で
「7.9 = infra 完備、本番計測は 7.10/7.11/7.12 chain で
実施」と判断する形が妥当。Compile-pass 27/55 + run-stage
infra (d-1..d-4) + spill-aware 完備 (d-8) で 7.9 を
"infra-complete" として close する選択肢を 7.13 で議論。

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
