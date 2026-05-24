# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: this commit (10.J-0 amend round — ADR-0109
  Status: Proposed → Accepted; ADR-0025 Superseded; D-075
  re-scoped to impl tracker; `docs/zig_api_design.md` §4 + §5 +
  §8 reconciled with ADR-0110 (16-byte Value); ROADMAP §10 new
  row 10.J inserted before 10.F; phase_log/phase10.md row 10.F
  + 10.J added; phase10_design_plan_ja.md §3.6 + §7 work
  sequence amended; phase9_close_master.md / phase9_remaining
  _flow.md / phase9_value_widen_plan.md Doc-state notes
  added)。直前: `142502a5` D-171 minimum-viable global accessors
  (10.F sub-chunk; 並行)。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。

## Active task — 10.J-invest (pre-impl investigation + execution plan + integrated test strategy)

**NEXT chunk** per ROADMAP §10 / 10.J + ADR-0109 Revision 2026-05-25:

`src/zwasm.zig` の native Zig API rewrite (Engine + Linker +
TypedFunc + Memory) を始める前に、subagent 駆動で以下を作る:

1. **コードベース調査** — 現状 `src/zwasm.zig` / `src/api/` /
   `src/runtime/runtime.zig` / 全 import 元 / ABI surface (JIT-
   emitted code が読む `[X19 + offset]` 含む) を survey し、
   ADR-0109 + `docs/zig_api_design.md` の native facade に
   寄せる場合に「何をどれだけ変更しなければならないか」を
   site 単位で列挙。
2. **実行計画 (execution plan)** — 調査結果を総括して J.1+
   sub-chunk decomposition + dependency order + per-chunk
   exit criterion を確定。Runtime → JitRuntime rename を
   最初に下ろす (10.M/R/TC/E/G の rename churn 回避)。
3. **統合テスト戦略** — plan doc 内に **テスト設計** も含む。
   「どうあれば良いテストになるか」を考えながら、regression
   detection + happy path + edge cases を網羅し、「他の test
   が通過しても Zig API が壊れている」が起きない構造を組む。
   API usage パターン出し (ADR-0109 §3.1-§3.8 → 拡張可) +
   既存 fixture (`test/realworld/wasm/cljw_*.wasm` /
   `test/edge_cases/p*/`) appendable な leverage を含む。

**Output**: plan doc (場所 TBD — investigation 結果次第)。
**Gating**: plan doc landing 後 user review → 承認後 J.1+ 開始。

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
