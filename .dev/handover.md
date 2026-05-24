# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: this commit — **10.J-invest 完了** (plan doc
  [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md) 1140+
  lines; 2 subagent surveys at `private/notes/p10-J.invest-{code,
  test}-survey.md` の synthesized 結果; 8 chunks J.1..J.close +
  three-tier test architecture + coverage matrix + 7 decision
  points + 10 risks)。直前: `11c6e94e` (J.0 amend round)。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。

## Active task — 10.J-1 待機中 (USER REVIEW GATE)

**ガイド**: plan doc [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md)
を review し、特に以下を確認/承認お願いします:

- **§3 chunk decomposition** (J.1-J.close 8 chunks; J.4 critical path)
- **§4 integrated test strategy** (Tier 1/2/3 architecture; 「他 test
  green でも Zig API 壊れている」を構造的に防ぐ仕組み)
- **§5 decision points D1-D7** — 推奨判断が frozen 済 (Option B
  subsystem split / J.4 spike contingency / Tier-2 corpus realworld+p7
  only / WASI skeleton-only / etc)。ユーザ override 可。
- **§6 risk inventory R1-R10** — TypedFunc comptime / 名前衝突等
- **§7 cycle estimate** 8-12 cycles (ADR-0109 estimate 6-8 を上回るが
  J.4 spike contingency + J.6 Tier-2 runner exe を visible scope に
  含めた結果; どちらも scope-creep ではない)

**承認後**: J.1 (Runtime → JitRuntime mechanical rename) から impl 開始。
否承認/修正要求あれば plan doc を amend してから再 review。

## 10.J 完了後 / 10.F 残り (並行) — chunk order

- **10.F 残り** (`src/api/instance.zig` 側; 10.J と独立; いつでも
  挿入可能): D-171 `_new`/`_type` + D-172 (table) + D-173 (memory)
- 10.Z (ZirInstr 128-bit 拡張; Z.1 直接実装)
- 10.D (ADR-0111-0117 + ROADMAP §12 amend 設計ラウンド)
- 10.T (test infra: corpus import / stress runners / emit_test
  baseline / realworld skeleton)
- 10.M (memory64) → 10.R (function-refs) → 10.TC (Tail Call)
  → 10.E (EH) → 10.G (WasmGC)
- 10.P (Phase 10 close: invariants script + widget 10→DONE)

## Audit follow-up (4 soon items; cleanup chunk候補)

audit-2026-05-24-phase9-close.md `soon` セクション (10.J / 10.F
の合間に消化候補):

- **ADR-0078 paired-artifact drift** — 3 SKIP-* rows (D-157 /
  D-162 / D-163) reference discharged debts; table 更新 OR
  SKIP-* emission retire。
- **Spike lifecycle hygiene** — 7 件 (2 merged-into-prod 残置 +
  5 pre-skeleton no-README)。
- **ADR `<backfill>` 5 件 (ADR-0107 含む)**。
- **Debt 26 rows > 15 threshold + Phase 9 boundary** → `meta_audit`
  suggest; user-gated per `meta_audit/SKILL.md`; do NOT
  autonomously fire。

## Cold-start procedure

Per `/continue` SKILL.md Resume Steps 0.5 / 0.7 / 0.8。Step 0.8
の `scripts/check_phase9_close_invariants.sh --gate` は Phase 9 =
DONE 後 permanent regression check として残存 (I7 ARCHIVED-IN-PLACE
受理済; 18/18 PASS)。

**Phase 10 設計の authoritative source**:
[`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3-§8
(2026-05-25 amend: §3.6 ADR-0109 sub-section + §7 J.* chunks)。
**Zig API consumer spec**: [`../docs/zig_api_design.md`](../docs/zig_api_design.md) (live; ADR-0109 Accepted)。

## See

- [`../docs/zig_api_design.md`](../docs/zig_api_design.md) —
  Zig API consumer spec (ADR-0109 paired; live)
- [`decisions/0109_native_zig_api_inversion.md`](./decisions/0109_native_zig_api_inversion.md)
  — Accepted 2026-05-25; impl tracker = D-075 + ROADMAP §10 / 10.J
- [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) — r3 + 2026-05-25 amend
- [`phase_log/phase10.md`](./phase_log/phase10.md) — sub-chunk record
- [`phase9_close_master.md`](./phase9_close_master.md) —
  ARCHIVED-IN-PLACE 2026-05-25; cite-only
- ROADMAP §10 (12 sub-rows incl. new 10.J)
- `private/audit-2026-05-24-phase9-close.md` (gitignored)
