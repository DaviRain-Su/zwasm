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

## Current state — Phase 7 / §9.7 / 7.7 IN-PROGRESS

直近 commit (HEAD = `0fea402`):

- `0fea402` workflow: SKILL.md hard-gate Detection rule (2 checkpoints) + handover gate awareness
- `08dc2ef` 🔒 Phase 7→8 transition gate registered (§9.7 / 7.13 + `phase8_transition_gate.md`)
- `b42eaea` workflow efficiency overhaul (parallel test gate + chunk granularity + opt-log seed)
- `93fbbd2` / `a3b0157` / `837d067` opt-log F-NNN seed → R-NNN trigger column → English translation
- `d638cc7` chore(p7) §9.7 / 7.7-fp-mem [x] flip
- `3255c29` §9.7 / 7.7-fp-mem (4 ops; 6 tests; 3-host green)
- `401551e` windowsmini Defender exclusion setup procedure persisted

**Active task**: User-introduced pause 完了 (作業効率化 + Phase 8
gate + optimisation_log 整備済)。再開後の **NEXT** =
`7.7-fp-end-fix` (D-032 discharge — `MOV EAX, src` を i64/FP
result でも正しく返すよう end handler を分岐)。続いて 7.8 spec
gate (Linux + Windows hosts) → 7.9/7.10 realworld → 7.11 🔒
three-way differential → 7.12 audit → **🔒 7.13 hard gate** →
7.14 open §9.8。

> **🔒 Phase 7 → 8 hard gate** が §9.7 / 7.13 に登録済。
> Autonomous /continue loop は 7.13 row を発見した時点で
> ScheduleWakeup を skip して user に surface する規律
> ([`phase8_transition_gate.md`](phase8_transition_gate.md) +
> `.claude/skills/continue/SKILL.md` §"Exception — hard
> human-in-loop transition gates")。Detection は 2 checkpoint
> (Resume Procedure Step 2 + Step 7 re-target) で発火。
> Gate checklist は (1) functional completion / (2) debt
> reconciliation / (3) AOT/Wasm 3.0/WASI/SIMD horizon の
> design cleanliness / (4) optimisation_log triage /
> (5) meta_audit + strategic review の 5 section。

**Phase**: Phase 7 (ARM64 + x86_64 baseline、ADR-0019)。
**Branch**: `zwasm-from-scratch`。

## §9.7 / 7.7 chunk progress

完了済 27 chunk: skel / alu / cmp / eqz / shift / bitcount / locals /
control-{skel,if,table} / mem-{load,store} / globals / wrap /
call-{direct,indirect} / fp-{const,binary,compare,unary,copysign,
minmax,convert-{simple,unsigned},trunc-sat-{signed,u32,u64},
trunc-trap-{signed,unsigned},mem}。SHA は `git log
--grep='§9.7 / 7.7-'` で取得可能。

| # | Chunk | Status |
|---|---|---|
| 7.7-fp-end-fix | FP-aware function-end (D-032 discharge) | **NEXT** |
| deferred-Win64 | Win64 ABI table + Cc enum | pending |

ADR-0019 phase plan post-7.6: 7.7 emit.zig, 7.8 spec gate (Linux
+ Windows hosts), 7.9/7.10 realworld, 7.11 3-way differential
🔒。ADR-0021 Revision history (sub-split + emit_test extraction)
は phase boundary batch update で。

## ADR-0025 (Zig host API) implementation chain

Phase A (design + ROADMAP §10 sync) DONE。Phase B-1〜B-5 (thin
facade + TypedFunc + WasiConfig + ImportEntry + examples) +
Phase D (migration doc) は post-7.5d sub-b 着手予定。詳細は
`.dev/decisions/0025_zig_library_surface.md` Revision history。
ADR-0025 self-review で 8 issues 起こり、すべて Revision history
row 2 で addressed (cross-module *Module → *Instance / facade の
zone placement / "constant overhead" / WASI prereq 等)。

## Open structural debt (pointers)

- **D-022** Diagnostic M3 / trace ringbuffer — Phase 7 close 後再評価。
- **D-026** env-stub host-func wiring (cross-module dispatch)。
- **D-032** FP-aware function-end — 次タスク `7.7-fp-end-fix` で discharge 予定。
- emit.zig / inst.zig / emit_test.zig / api/instance.zig は soft-cap 圏内、hard-cap discharge 済。
- 詳細・staleness check は `.dev/debt.md`。

## Recently closed (full history via `git log --oneline`)

- §9.7 / 7.7-fp-mem (3255c29): emitMemOp に is_fp 分岐 + encMovssMovsdMemBaseIdx; 6 tests。
- §9.7 / 7.7-fp-trunc-trap-{signed,unsigned} (eff1c75 / 78d5b06): Wasm 1.0 trapping f→i 8 ops。
- §9.7 / 7.7-fp-trunc-sat-{signed,u32,u64} (20a2c0e / 18314cf / 7983dd3): Wasm 2.0 saturating 8 ops。
- §9.7 / 7.7-fp-convert-{simple,unsigned} (2e60605 / df99e67): promote/demote/reinterpret + signed/unsigned i→f。
- §9.7 / 7.7-fp-{minmax,copysign,unary,compare,binary,const} 系: SSE2 全 surface (1205ae0 / 6af5239 / d51c1b8 / bc4348d / 895ac3e / f062800)。
- §9.7 / 7.7-call-{direct,indirect} + 7.7-wrap (d071173 / 2248e03 / 12cd04c)。
- §9.7 / 7.7-mem-{load,store} + globals + control 系 + i32 ALU 全 surface (c0711fb..59ed705)。
- §9.7 / 7.6 a/b/c (739de07 / 3c78b63 / 344d393)。
- §9.7 / 7.5d 完全クローズ (sub-b chunks 1-10) (48b9745)。
- ADR-0023 §7 18 items + ADR-0024 + ADR-0025 (Phase A) DONE。
