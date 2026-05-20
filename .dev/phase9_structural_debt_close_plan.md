# Phase 9 構造的負債 close plan

> **Status**: Proposed 2026-05-20。`/continue` Step 1a の
> close-plan override に hooked済み — handover.md がこの doc
> を Cold-start procedure step 1 で参照することで、次セッ
> ションは ROADMAP §9.<N> の通常 task より先にこの plan の
> §6 Work sequence を実行する。
>
> **STOP**: §6 が完了するまで **D-153 / B159 以降の cross-
> module imports work は触らない**。架構改造 in flight は
> 凍結。`.dev/lessons/2026-05-20-refactor-tradeoffs-honest-
> accounting.md` の経緯参照。

## §1. なぜ存在するか

セッション 2026-05-20 (38 chunks, B121→B158, 複数 auto-
compact) の終盤に、user 直接要請で「大リファクタ全期間で
の妥協 honest accounting」を実施。中間状態 (D-153 在中の
unfinished helper など) ではなく、**持続的に問題になり続け
る / 負債として残り続ける構造的問題** を列挙した。

D-153 (12 cycle 経過時点で skip-impl 不動) はそれ自体が
複数の構造的アンチパターンの表面化:

- file_size_check cap 反応が「コメント圧縮」第一になる
- helper 先 land → wire-up 別 cycle = 本番上の spike
- architectural piece に chunk granularity rule が機能しない
- handover.md が ≤ 80 行 self-rule を完全に逸脱 (273 行)

これらを片付けてから D-153 を**設計から仕切り直す**。

## §2. Issues by category

### A. Claude指示体系 (skill / rule) のギャップ

| ID | Issue |
|---|---|
| A1 | `handover.md ≤ 80 lines` rule 自己破綻 (現状 273 行)。chunk progress table の累積が原因。退避 hook 無し。 |
| A2 | chunk granularity "5-15 ops per chunk" rule が architectural work で機能しない。emit/handler 専用 rubric。 |
| A3 | spike discipline (`no_workaround.md` + `extended_challenge.md` Step 4) に teeth 無し。「helper を先 land して wire-up を別 cycle」が本番ブランチ上の spike として黙認されている。B151/B156 revert はこの表面化。 |
| A4 | session-budget / compact 認識の不在。1 session 38 chunks 想定外。compact 越しの中間推論喪失。 |
| A5 | subagent 出力 path 不整合 (project-local vs ~外部 path)。subagent prompt template に絶対パス明文無し。 |

### B. 意思決定 patterns の構造的歪み

| ID | Issue |
|---|---|
| B1 | file_size_check 反応が「コメント圧縮」第一。「split ADR を切る」が永久に短期最小コスト負け。 |
| B2 | `blocked-by` debt の積算 (88 行中 33 行)。Step 0.5 barrier-dissolution check は走るが長期 barrier には届かない。 |
| B3 | 「1 more chunk」終わらせる病。architectural piece の cycle 数上限が無い。 |
| B4 | lessons vs handover 責任 drift。観察事項を handover 内 narrative に書く運用が定着、lesson 化されない。次セッションがゼロから同じ罠を踏むリスク。 |

### C. 構造的コード / process 改善

| ID | Issue |
|---|---|
| C1 | `runner.zig` 2000 LOC 張り付き (1995-2000 行 sail close to wind)。新 helper が全て `engine/export_lookup.zig` 等へ逃げ、命名 vs 実体乖離。D-141 が永久 blocked-by。 |
| C2 | `tally.skipped` field 名 vs 内容乖離。`skip-impl` 表現だが manifest skip-impl + runtime SKIP event 両方を counter。私自身複数回 misread。ADR-0050 ratchet も同 field 計上。 |
| C3 | spec runner SKIP-* token 体系が ADR 規律外。`SKIP-NON-INVOKE-ACTION` (B137 land) は skip_adr++ だが対応 ADR 無し。どれが ADR 必須でどれが不要か不明。 |
| C4 | spec_assert と c_api Instance 経路の分離 (D-139)。v0.1.0 RC latent bug リスク。filed only, scheduling 無し。 |
| C5 | handover に chunk table を蓄積する pattern そのもの (A1 直接原因)。「進捗の根拠」を handover に集める誤運用 (正しくは git log)。 |

### D. ROADMAP 連動

| ID | Issue |
|---|---|
| D1 | §9.12 "skip-impl == 0" exit criterion 自体。cross-module imports (100 sites)、v128 cross-module (D-079)、windowsmini SEH (D-136) が architectural blocker として残存。exit のため architectural piece を多段 land する pattern が常態化。 |
| D2 | ROADMAP §9.<N> task row vs commit graph vs handover chunk table vs debt.md の 4 場所で進捗情報分散。authoritative source 曖昧 (skill は ROADMAP wins と書くが実運用は handover 優先)。 |

## §6. Work sequence

各 step は **acceptance criterion で gating**。前 step
未完了で次 step に進まない。1 step = 1 cycle 目安。

### (a) handover.md cleanup — A1 + C5 解消

- chunk progress table (現 B1〜B158) を `.dev/phase_log/p9_12_B_chunks.md` に移管
- handover.md は close-plan へのポインタ + active task + open questions のみ
- **Accept**: `wc -l .dev/handover.md` ≤ 80

### (b) chunk type taxonomy — A2 解消

- `.claude/skills/continue/LOOP.md` に "chunk types" section 追加
- type ∈ {`emit`, `architectural`, `survey`, `test-only`, `infrastructure`}
- 各 type の granularity rule (`emit` = 5-15 ops; `architectural` = spike-first; `survey` = single-cycle subagent; etc.)
- chunk-table format に `type` column 追加 (移管先 phase_log のスキーマで)
- **Accept**: LOOP.md updated + phase_log schema reflects type

### (c) architectural piece cycle cap — B3 解消

- LOOP.md に rule 追加: "architectural" type chunk が 3 cycles 経過しても measurable progress (test count delta、fail count delta) なき場合、**mandatory step-back**
- step-back = (i) HEAD を最後の green に reset, (ii) `private/spikes/` に退避, (iii) design ADR 起草必須
- D-153 はこのルールが既に適用される (12 cycles 既経過)
- **Accept**: rule landed in LOOP.md

### (d) spike discipline 厳格化 — A3 解消

- 新規 `.claude/rules/architectural_spike.md`
- 「behavior 観測点を持たない code commit は `private/spikes/` でしか許可しない」
- 「helper 先 land → wire-up 別 cycle」は anti-pattern として明文化
- `no_workaround.md` から cross-reference
- **Accept**: rule file 存在、`audit_scaffolding §G` に grep check 追加

### (e) tally field rename — C2 解消

- `test/spec/spec_assert_runner_base.zig::AssertTally`:
  - `skipped` → `manifest_skip_impl` (rename)
  - 新規 field `runtime_skip` 追加
  - skip-impl は manifest skip-impl line 専用 counter に厳密化
- 全 consumer 更新 (skip_impl_history.yaml ratchet 計算含む)
- 既存 entry の互換性確認 (history は manifest_skip_impl 値で recompute)
- **Accept**: test-all green、`bash scripts/check_skip_impl_ratchet.sh --gate` exit 0

### (f) skip-token taxonomy ADR — C3 解消

- 新規 `.dev/decisions/00NN_spec_runner_skip_token_taxonomy.md`
- 既存 SKIP-* token 列挙 (V2-InstanceAllocFailed / VALIDATOR-GAP / PARSER-GAP / CROSS-MODULE-IMPORTS / NO-LINK-TYPECHECK / NON-INVOKE-ACTION / WASMTIME-UNUSABLE)
- 各 token の class (debt-trackable / ADR-required / runner-internal) 定義
- `check_skip_impl_ratchet` の token-class 認識追加
- **Accept**: ADR Proposed、existing token 全て classified

### (g) D-141 runner.zig split ADR — B1 + C1 解消

- 新規 `.dev/decisions/00NN_runner_zig_split.md`
- "blocked-by: substrate audit Q3" を **解除** (B1 の構造的歪みを最終的に止める)
- split target: `engine/runner.zig` (現 1995 行) を 2-3 file に分割
  - 候補: `runner.zig` (top-level driver), `compile.zig` (compileWasm + globals layout), `setup.zig` (init helpers)
- ADR は **Proposed まで** ; 実 split work は別 cycle (この plan の scope 外)
- D-141 row の `blocked-by:` を新 ADR 番号に更新
- **Accept**: ADR Proposed、D-141 unblocked

### (h) blocked-by escalation — B2 解消

- `.claude/skills/audit_scaffolding/CHECKS.md §F` 拡張
- rule: `blocked-by:` row の `Last reviewed` が 3 cycles 経過 → 自動 escalate (re-evaluation 必須)
- 5 cycles 経過 → ADR or lesson 起草必須
- 現状 33 blocked-by rows をこの基準で再評価
- **Accept**: CHECKS.md updated、initial sweep 結果 commit

### (i) Phase 9 exit redefinition ADR — D1 解消

- `.dev/decisions/00NN_phase9_exit_redefinition.md` (or amendment to ADR-0056 / ADR-0062)
- 現 exit: "skip-impl == 0 on all 3 hosts"
- 新 exit: "skip-impl == 0 OR every residual blocked by named-successor-phase ADR"
- D-079 / D-136 / D-153 (cross-module imports) を successor phase に escape valve
- §9.12-E ロックインを解除
- **Accept**: ADR Proposed (要 user collab for Phase 9 完備 redefinition なので Status: Proposed で stop)

### (j) D-153 resume

- (a) 〜 (i) 全て land 後、再開
- 新しい設計: `.claude/rules/architectural_spike.md` に従い `private/spikes/d153/` で spike → design ADR → impl chunks
- 既存 B146〜B158 commits は維持 (preparatory infra として有効)
- **Accept**: 新規 `.dev/decisions/00NN_cross_module_imports_design.md` Proposed

## §7. Hard constraints

- **D-153 / B159 以降の cross-module imports work には触らない** (§6 (j) まで)
- B146〜B158 の commit を revert しない (preparatory infra として有効、後段で再活用)
- file_size_check が新規 WARN を出した時点で「ADR-file-split 起草」を debt 起票 (B1 再発防止)
- 各 step の commit message に `[close-plan §6 (X)]` tag 必須

## §8. References

- `.dev/lessons/2026-05-20-refactor-tradeoffs-honest-accounting.md` — 観察記録
- `.dev/debt.md::D-154` — umbrella tracking row
- `.dev/phase_log/p9_12_B_chunks.md` — handover から移管された chunk table (step (a) で生成)
