---
name: refactor-tradeoffs-honest-accounting
description: zwasm v2 大リファクタ全期間の妥協 honest accounting (2026-05-20)。中間状態ではなく持続的構造問題のみ。
metadata:
  type: project
---

# 大リファクタ全期間 honest accounting

## Citing

- `.dev/archive/phase9/phase9_structural_debt_close_plan.md` §6 が actionable
  work sequence (この lesson は経緯記録)
- `.dev/debt.md::D-154` (umbrella tracking row)

## 経緯

セッション 2026-05-20 (B121→B158 = 38 chunks、複数
auto-compact)、user が「大リファクタ全期間で妥協してい
る点」を honest に列挙するよう直接要請。中間状態は除外
し、**持続的に問題になり続ける / 負債として残り続ける
構造的問題** に絞った。

D-153 (12 cycle 経過時点で skip-impl 192 不動) はそれ
自体が複数の構造的アンチパターンの表面化で、close-plan
で順次解消してから D-153 を仕切り直す方針となった。

## 4 カテゴリ × 持続問題

### A. Claude指示体系 (skill / rule) のギャップ

- **A1**: `handover.md ≤ 80 lines` self-rule 自己破綻
  (現状 273 行)。chunk table 累積。
- **A2**: chunk granularity "5-15 ops" rule が
  architectural work で機能しない。
- **A3**: spike discipline に teeth 無し。「helper 先
  land → wire-up 別 cycle」が本番 spike として黙認。
  B151/B156 revert で表面化。
- **A4**: session-budget / compact 認識不在。38 chunk
  / 複数 compact が想定外。
- **A5**: subagent 出力 path 不整合 (project-local vs
  ~外部 path)。

### B. 意思決定 patterns の構造的歪み

- **B1**: file_size_check 反応が「コメント圧縮」第一に
  なり、「split ADR」が永久に短期最小コスト負け。
- **B2**: `blocked-by` debt 積算 (88 行中 33 行)。
  long-term barrier に届かない。
- **B3**: 「1 more chunk」終わらせる病。architectural
  piece の cycle 数上限が無い。
- **B4**: lessons vs handover 責任 drift。観察事項を
  handover narrative に書く運用で lesson 化されない。

### C. 構造的コード / process 改善

- **C1**: `runner.zig` 2000 LOC 張り付き。新 helper が
  全て `engine/export_lookup.zig` 等へ逃げ、命名 vs
  実体乖離。
- **C2**: `tally.skipped` field 名 vs 内容乖離。
  manifest skip-impl + runtime SKIP event 両方を
  counter。ADR-0050 ratchet も同 field 計上。
- **C3**: SKIP-* token 体系が ADR 規律外。
  `SKIP-NON-INVOKE-ACTION` (B137) は対応 ADR 無し。
- **C4**: spec_assert と c_api Instance 経路の分離
  (D-139)。v0.1.0 RC latent bug リスク。
- **C5**: handover に chunk table を蓄積する pattern
  そのもの (A1 直接原因)。

### D. ROADMAP 連動

- **D1**: §9.12 "skip-impl == 0" exit criterion 自体が
  architectural blocker (cross-module / v128 / SEH) を
  Phase 9 内で消化する圧力を生む。
- **D2**: 進捗情報が 4 場所で分散 (ROADMAP / handover
  table / debt / commit graph)。authoritative source
  曖昧。

## なぜ persistent (中間状態と区別された判断)

各 issue は **次の D-NNN を解消しても消えない**:

- A1 / C5: 制度的に handover を「chunk-log」化する
  習慣が残る。
- A2 / B3: emit/handler 中心の rule が architectural
  work には常に inadequate。
- A3 / B1: 「先 land」「コメント圧縮」が短期最適解で
  ある限り、新しい architectural piece でも再発。
- C2: tally field 名 を直さない限り、新 SKIP token を
  追加する度に同じ misread リスク。
- D1: Phase 9 exit を直さない限り、新規 architectural
  blocker が見つかる度に Phase 9 内消化圧力が再発。

## 次セッションでの hook 方法

`.dev/handover.md` の `Cold-start procedure` step 1 を
`.dev/archive/phase9/phase9_structural_debt_close_plan.md` への
ポインタに置換。`/continue` Step 1a (close-plan
override) が発火し、ROADMAP §9.<N> task より先に
close-plan §6 を実行する。

D-153 / B159 work は §6 (j) まで凍結。
