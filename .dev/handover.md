# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: this commit — **10.J plan APPROVED** + cw v1
  naming 正規化 (zwasm v2 docs 全 "CW v2" / "ClojureWasm v2" →
  "cw v1" / "ClojureWasm v1"; `cw_guest_setup.md` 内 OLD
  ClojureWasm/ refs → "cw v0" 別途明示); `docs/zig_api_design.md`
  §2 Value snippet を ADR-0110 16-byte uniform に整合;
  `phase10_zig_api_plan_ja.md` 削除 (英語版 canonical)。直前:
  `c50e9ed1` (A+C: table_storage.zig 削除 + audit_table_sync.sh
  gate)。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。

## Active task — 10.J impl train (J.1..J.close 自走中)

**ADR-0109 (Accepted 2026-05-25) + plan doc** [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md) **user 承認済** (D1-D7 frozen / 5 must-have / R1-R10)。**J.1 から J.close まで /continue loop 自走**; 各 sub-chunk close 時に handover が次 sub-chunk へ retarget; 8-12 cycles 想定; per-sub-chunk user 承認 不要。

| Sub-chunk | Scope | Gate | Status |
|---|---|---|---|
| **J.1 NEXT** | Runtime → JitRuntime 機械 rename (~25 import sites) | `unclear` → test-all | 着手準備完了 |
| J.2 | Engine + Module + allocator strict-pass | substrate | J.1 後 |
| J.3 | Instance + 完全 Trap set | substrate | J.2 後 |
| J.4 | TypedFunc + Memory + multi-result (**critical path**; spike 可) | substrate | J.3 後 |
| J.5 | Linker + Caller + host imports | substrate | J.4 後 |
| J.6 | Tier-2 zig_facade_runner | cohort | J.5 後 |
| J.7 | WASI defineWasi skeleton | substrate | J.6 後 |
| J.close | Coverage audit + D-075 close + ROADMAP 10.J [x] | substrate | J.7 後 |

**J.1 exit criterion**: (1) `grep -nE '\bruntime\.Runtime\b' src/ test/` 0 hit; (2) `zig build test-all` GREEN; (3) `zig build lint` GREEN。**Tier-1 tests landed in commit**: NONE NEW (rename; 既存 tests が挙動不変 prove)。**Risk**: LOW (survey §3 "mechanical 90% search-replace")。詳細 plan §3 J.1。

## Phase 10 progress (stable snapshot; refreshed on row [x] flip only)

Full row text + per-row exit criteria live in ROADMAP §10 task
table (12 rows; /continue Resume Step 2 lands there first).
Original Phase 10 scope (memory64 / fn-refs / TC / EH / GC)
is unchanged by 10.J insertion — design in
`phase10_design_plan_ja.md` §3.1-§3.5.

| Row | Status | One-line |
|---|---|---|
| 10.0 | [x] | Phase 9→10 transition; widget 9→DONE; §10 inline expand |
| 10.C9 | [x] | Phase 9 close 後始末 (audit + SHA backfill + bench baseline + master plan archive) |
| 10.J | [ ] **ACTIVE** | Native Zig API (ADR-0109; 8-12 cycles) — see [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md); inserted 2026-05-25 |
| 10.F | [ ] partial | c_api scalar accessors (D-171 minimum-viable landed `142502a5`; D-171 `_new`/`_type` + D-172 + D-173 remain; can land parallel to 10.J — different file) |
| 10.Z | [ ] | ZirInstr 128-bit 拡張 (`payload: u32 → u64`; full 4-host re-green) |
| 10.D | [ ] | ADR-0111..0117 + ROADMAP §12 amend 設計ラウンド (7 ADRs Accepted) |
| 10.T | [ ] | Test infra (corpus import / stress runners / emit_test baseline / realworld skeleton / BLESS workflow) |
| 10.M | [ ] | memory64 + multi-memory enable |
| 10.R | [ ] | function-references prereq (5 ops + `(ref $sig)` typing; GC prereq) |
| 10.TC | [ ] | Tail Call (regalloc terminator-class extension + ops + interp trampoline) |
| 10.E | [ ] | Exception Handling (callsite_metadata + EH ops + unwind + cross-module propagation) |
| 10.G | [ ] | WasmGC (Value.anyref / heap + collector + RTT / i31 / op_gc / mark-sweep β) |
| 10.P | [ ] | Phase 10 close (invariants script + widget 10→DONE + Phase 11 inline expand) |

**Currently active**: 10.J (~10 row pending after; Phase 10 is
not nearly complete at 10.J close).

## Audit follow-up (4 soon items)

`private/audit-2026-05-24-phase9-close.md` `soon` セクション
(10.J/10.F の合間に消化候補): ADR-0078 paired-artifact drift
(3 SKIP-* rows); spike lifecycle hygiene (7 件); ADR `<backfill>`
5 件; debt 26 rows + Phase 9 boundary → `meta_audit` suggest
(user-gated; NOT autonomously fired)。

## Cold-start procedure + key refs

Per `/continue` SKILL.md Resume Steps 0.5 / 0.7 / 0.8。Step 0.8
`scripts/check_phase9_close_invariants.sh --gate` (18/18 PASS) は
Phase 9 = DONE 後 permanent regression check として残存。

- **10.J impl 順序**: [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md) §3 (J.1..J.close)
- **Phase 10 全体設計**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1-§3.6 + §7 work-sequence
- **Zig API spec**: [`../docs/zig_api_design.md`](../docs/zig_api_design.md) (live; ADR-0109 Accepted)
- **ADR-0109**: [`decisions/0109_native_zig_api_inversion.md`](./decisions/0109_native_zig_api_inversion.md) (impl tracker = D-075 + ROADMAP §10 / 10.J)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md) (rows 10.C9 + 10.F + 10.J)
- **Phase 9 close master**: [`phase9_close_master.md`](./phase9_close_master.md) (ARCHIVED-IN-PLACE 2026-05-25; cite-only)
- ROADMAP §10 = task table (12 行); audit report = `private/audit-2026-05-24-phase9-close.md` (gitignored)
