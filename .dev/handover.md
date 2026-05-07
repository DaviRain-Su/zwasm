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

- `<this>` chore(p7): §9.7 / 7.9 chunk d-2 close (WASI dispatch handlers)
- `6800bb7` feat(p7): §9.7 / 7.9 chunk d-2 — WASI dispatch handlers + first run-stage host call
- `95d5ec8` feat(p7): §9.7 / 7.9 chunk d-1 — host-import dispatch infrastructure
- `ceb5b1e` feat(p7): §9.7 / 7.9 chunk c3 — i{32,64}.div_s INT_MIN/-1 overflow trap

**Phase status**: §9.7 / 7.5 + 7.8 → **[x]**。Phase 7 残 row = 7.9 /
7.10 / 7.11 🔒 / 7.12 / 7.13 🔒。

**§9.7 / 7.9 progress**: chunks a..d-2 closed across 9 commits。
3-host gate green: spec_assert 212/0/20 + realworld 55/0 + wast
1158+72/0 + edge_cases 32/0 + new wasi-jit-dispatch unit tests
across Mac / OrbStack Linux / windowsmini Win。

**Chunk 7.9-d-2 完了** (`6800bb7`): real WASI handlers wired:
- `src/wasi/jit_dispatch.zig` — `fd_write` (iov walk + bounds
  check + nwritten write; stdout routing deferred), `clock_time_
  get` / `random_get` (deterministic stubs writing 0), args /
  environ stubs returning 0/empty。
- `lookup(module, name)` matches wasi_snapshot_preview1 +
  wasi_unstable; `populateDispatch` walks imports in wasm-space
  order filling per-fn-idx slots。
- `runner.zig.runI32Export` re-decodes imports section, calls
  populateDispatch, hands the dispatch slice to JitRuntime。
- End-to-end smoke `test/edge_cases/p7/wasi/fd_write_badf.{wat,
  wasm,expect}`: imports fd_write, calls with fd=99, expects
  i32:8 (EBADF). Mac edge_cases 31→32 PASS — first realworld
  WASI host-call via JIT works end-to-end。

**Chunk 7.9-d-3 plan** (NEXT): the proc_exit + real I/O finish:
- `proc_exit(rt, code)` — extend JitRuntime tail with
  `proc_exit_code: u32`; handler sets trap_flag = 2 (PROC_EXIT
  sentinel) + writes code; entry shim's post-return check
  surfaces (Trap-vs-ProcExit-vs-Value) to the host.
- Thread `init.io: std.Io` through JitRuntime so `fd_write`
  routes to actual stdout / stderr。
- Replace `clock_time_get` zero-stub with real wall-clock;
  `random_get` with std.posix.getrandom (gated by zig-stdlib
  detection).
- Update `test/realworld/run_runner_jit.zig` to invoke the entry
  via entry.callVoidNoArgs (per `_start` export sig); report
  run-pass count alongside compile-pass.
- 目標: §9.7 / 7.9 exit criterion = 40+ realworld run-pass via
  ARM64 JIT。

**Chunk 7.9-d-4 plan** (if needed): memory + data segment init
in JitRuntime — the runner currently uses `[0]u8` memory which
blocks fixtures that touch linear memory beyond pure host-call
dispatch (D-031).

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
