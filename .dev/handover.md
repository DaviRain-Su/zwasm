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

## Current state — Phase 7 / §9.7 / 7.8 IN-PROGRESS

直近 commit (HEAD = `<this>`):

- `<this>` chore(p7): §9.7 / 7.8-x86-jit-mem-windows close — Windows 49/174/20 → 105/110/20 (+56 PASS)
- `6db570c` fix(p7): §9.7 / 7.8-x86-jit-mem-windows — use 0.16 stable APIs
- `2748971` feat(p7): §9.7 / 7.8-x86-jit-mem-windows — Windows x86_64 RWX (D-045 chunk 12)
- `f5e5f5b` chore(p7): §9.7 / 7.8-x86-spec-gate — three-host spec_assert baseline

**Phase status**: §9.7 / 7.5 → **[x]** 完了。Phase 7 残 row = 7.8 /
7.9 / 7.10 / 7.11 🔒 / 7.12 / 7.13 🔒。**§9.7 / 7.8** = x86_64 spec
gate — D-045 active。chunks 1-12 完了。3-host baseline post-chunk-12:

- Mac aarch64       : **212 / 0 / 20**     (gate green — `test-all` wired)
- OrbStack Linux    : **109 / 106 / 20**   (unchanged — Linux 不依存)
- windowsmini Win   : **105 / 110 / 20**   (was 49/174/20 → +56 PASS)

Linux ↔ Win 差 = 4 PASS (vs 60 before chunk 12)。両ホスト共通の
**残 ~106 fail = SlotOverflow** が主因 (regalloc pool 6 reg を 5+
params で枯渇 — arm64 D-036/D-037 staged-spill machinery が
prior-art)。次の主軸 = **7.8-x86-spill-aware-regalloc** (両ホストで
106 fail を大量 close 見込み)。test-all 配線は Mac aarch64 のみ維持
(§9.7 / 7.8 row close = fail==0 で flip)。

**Active priority — §9.7 / 7.8 D-045 chunk chain**:

1. ☑ 7.8-x86-ctrl-stack — nop + drop + return
2. ☑ 7.8-x86-unreachable — JMP rel32 + unreach_fixups
3. ☑ 7.8-x86-i64-const — MOVABS r64, imm64
4. ☑ 7.8-x86-i64-alu — i64 ALU + cmp + bitcount + shift + rot (22 ops)
5. ☑ 7.8-x86-i64-mem — i64 load/store family (8 ops)
6. ☑ 7.8-x86-params-i32 — lift params=0 reject; i32-only marshal
7. ☑ 7.8-x86-params-i64fp — i64 / f32 / f64 params + type-aware locals
8. ☑ 7.8-x86-select — select / select_typed (CMOV)
9. ☑ 7.8-x86-mem-grow-size — memory.size + memory.grow + dead_code
10. ☑ 7.8-jit-mem-linux — Linux x86_64 mmap-RWX (+60 PASS)
11. ☑ 7.8-x86-spec-gate — three-host baseline measurement + comment refresh
12. ☑ **7.8-x86-jit-mem-windows** — Windows NtAllocateVirtualMemory RWX (Win +56 PASS)
13. **7.8-x86-spill-aware-regalloc** — mirror arm64 D-036/D-037 staged-spill (close ~106 SlotOverflow on both hosts) **NEXT**
14. 7.8-x86-misc-cleanup — residual UnsupportedOp + handcrafted_trap "did NOT trap"

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
- **D-031** runner runI32Export FP/i64 拡張 — JitRuntime memory init 後に at_limit 境界 fixture を再追加。
- **D-045** §9.7 / 7.8 close blocker — x86_64 backend gap (chunks 1-12 closed; chunks 13-14 残)。
- 詳細・staleness check は `.dev/debt.md`。

## Recently closed (full history via `git log --oneline`)

- §9.7 / 7.8-x86-jit-mem-windows (`2748971` + `6db570c`): Windows
  x86_64 RWX 配線。`std.os.windows.ntdll.NtAllocateVirtualMemory`
  + `NtFreeVirtualMemory` (zig 0.16 stable は wrapper-with-error-
  union 形を未公開のため低レベル extern 直接呼び)。typed packed
  struct (MEM.ALLOCATE { COMMIT, RESERVE } / MEM.FREE { RELEASE }
  / PAGE { EXECUTE_READWRITE }) でリクエスト。setExecutable /
  setWritable は Linux と同じく no-op (RWX page; x86_64 I/D
  coherent)。Windows spec_assert 49/174/20 → 105/110/20 (+56
  PASS, -64 FAIL)。Linux ↔ Win 4 PASS gap まで詰めた。3-host
  test-all green。`2748971` の初版が 0.16 master の wrapper を
  使ってしまい windowsmini で compile error → `6db570c` で
  ntdll 直接呼びに修正。
- §9.7 / 7.8-x86-spec-gate (f5e5f5b): three-host spec_assert
  baseline triangulation。Mac 212/0/20 / OrbStack 109/106/20 /
  Win 49/174/20。build.zig コメント更新、test-all 配線は Mac
  aarch64 限定維持。
- §9.7 / 7.8-jit-mem-linux (f4eccdc): Linux x86_64 mmap-RWX
  wiring (chunk 10)。OrbStack spec_assert 49/174/20 → 109/106/20
  (+60 PASS)。
- §9.7 / 7.8-x86-mem-grow-size (d138326): memory.size (SHR) +
  memory.grow (-1 skel) + dead_code tracking。
- §9.7 / 7.8-x86-select (af40c41): select / select_typed via
  CMOV (.q form)。
- §9.7 / 7.8-x86-params-i64fp (39142bd): i64 / f32 / f64 params
  + type-aware local.{get,set,tee}。
- §9.7 / 7.8-x86-params-i32 (7f9e9fe): i32-only param marshal
  (SysV / Win64)。
- §9.7 / 7.8-x86-i64-mem (bfedfdf): i64 load/store family (8 ops)。
- §9.7 / 7.8-x86-i64-alu (1e83c41): i64 ALU/cmp/bitcount/shift/rot
  (22 ops)。
- §9.7 / 7.8-x86-i64-const (e46aa7d): MOVABS r64, imm64。
- §9.7 / 7.8-x86-unreachable (98907dd): JMP rel32 + unreach_fixups。
- §9.7 / 7.8-x86-ctrl-stack (56b563b): nop + drop + return。
- §9.7 / 7.5 → [x] (5746f2b): validator wired into compileWasm;
  spec_assert 212/0/20 (= 0 skip-impl + 20 skip-adr)。
