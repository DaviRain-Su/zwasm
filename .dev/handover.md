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

直近 commit (HEAD = `6ff23a0`):

- `6ff23a0` feat(p7): §9.7 / 7.10 chunk i — x86_64 op_memory u32 offset (arm64 d-14 mirror)
- `053de68` chore(p7): mark §9.7 / 7.10 chunk h close
- `093906f` feat(p7): §9.7 / 7.10 chunk h — x86_64 op_control br/br_if function-depth (return path)
- `2dd5adf` chore(p7): mark §9.7 / 7.10 chunk g close

**Phase status**: §9.7 / 7.5 + 7.8 + **7.9 [x]**。Phase 7 残 row = 7.10 /
7.11 🔒 / 7.12 / 7.13 🔒。

**§9.7 / 7.10 progress** (Linux x86_64 realworld_run_jit 0/55 still):
- chunks a..i closed: D-029 ALU/FP parallel-move、op_call 全
  valtype marshal+capture、caller-side stack-args、localDisp
  + RBP/RSP disp32 encoder、op_control br/br_if function-depth、
  op_memory u32 offset (MOVABS+ADD lowering)。
- 各 chunk は dominant bottleneck を 1 つ解消するが、fixture は
  複数 gap を chain しているため compile-pass 数自体は 0/55。
  7.10 exit は bottleneck 枯渇=infra 完備で判断。Linux 7.10-i
  後の categorisation: SlotOverflow (regalloc pool 関連、D-029)
  + UnsupportedOp (param-arg-overflow 等) が dominant。

**§9.7 / 7.10 chain plan** (NEXT 群):
- **7.10-j (NEXT)**: SysV `i{32,64}-param-arg-overflow`
  (emit.zig:382/390/398/406)。我が関数が >5 i32/>3 mixed args
  を受け取るときの callee-side stack-arg READ path。Win64 側
  fallback は 7.10-f で既に存在 (line 362)。SysV 側は NSAA
  per-overflow counter + `[RBP+16+8*K]` 読み出しを追加。
  7.10-f の caller-side WRITE と対称的な mirror。
- 7.10-br_table-fdepth (deferred): emitBrTable で depth ==
  labels.len のケース。CMP + JNE rel8 + JMP の per-case 5-byte
  fixed shape を維持するには return-trampoline pattern が必要。
- 7.10-spill-disp32 (deferred to Phase 8): debt D-048。

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

- §9.7 / 7.10 chunks a..i closed (commits `a8777ac` `4fb4fcb`
  `68dd2dc` `da5db53` `6c523fa` `f47db77` `093906f` `6ff23a0`)。
  x86_64 JIT で D-029 ALU/FP、op_call 全 valtype、caller stack-
  args、localDisp + disp32、br/br_if function-depth、op_memory
  u32 offset を完備。realworld_run_jit 0/55 のまま (callee
  stack-arg read + SlotOverflow 残)。
- §9.7 / 7.9 [x] — arm64 realworld JIT 52/55 compile-pass。
