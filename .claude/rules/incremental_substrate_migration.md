---
description: "§9.12-B Q3 C 採用 per-op file 移行 + 全 layer DCE 拡張のインクリメンタル工程規律。1 chunk = 1 op or 1 layer; pinpoint revert OK; spike 多用 + 駄目筋は捨てる。"
paths:
  - "src/instruction/**/*.zig"
  - "src/feature/**/*.zig"
  - "src/ir/dispatch_collector.zig"
  - "src/cli/args.zig"
  - "src/api/wasm.zig"
  - "src/wasi/**/*.zig"
---

# Incremental substrate migration

> **状態**: skeleton (2026-05-19)。ADR-0073 (Proposed; build-option DCE
> substrate) で justify。§9.12-A 〜 §9.12-B で完成。

## The rule

Phase 9 完備の Q3 C 採択完成 (§9.12-B) は **インクリメンタルに**進める:

### 1 chunk = 1 単位

- 1 op の per-op file 化 (1 ZirOp tag → 1 file `<op>.zig`)
- 1 layer の declarative form 化 (CLI / c_api / WASI のいずれか 1 layer)
- 1 enforcement script の実装 (skeleton → working)

### Pinpoint revert

- 失敗したら commit を `git revert <sha>`; amend しない (`/continue` LOOP.md 規律)
- ratchet history yaml (skip_impl_history.yaml) に "rolled back, ADR-NNNN" entry
  追加
- 別アプローチで再度 spike から

### Spike を多用 + 捨てる

- `private/spikes/<slug>/` で実験 (`.claude/rules/spike_lifecycle.md` 参照)
- 採用なら `Status: merged-into-prod` + production commit cite
- 不採用なら `Status: rejected` + lesson 必須

### Progress tracker (machine-readable)

- `.dev/p9_completion_progress.yaml` で sub-row × op × layer matrix 更新
- 各 chunk close 時に commit が yaml に row 追加
- `bash scripts/p9_completion_status.sh` で live 状態確認

## Why

「労力厭わず」は「無理してでも一気に書く」ではなく「諦めずに何度でも試す」こと。
インクリメンタルに進めると、駄目筋を抱え込まず捨てる judgement が cheap になる。
Phase 9 完備の品質は、各 op の 1 ファイル化 + 5 軸 handler 集約 + build-option
DCE 達成度で測る; これらは 1 op ずつ進められる。

## Anti-patterns to avoid

- ❌ "Q3 C 採用は大工事だから一気に全 op 一度に書こう" (= 失敗時の revert が
  巨大になる)
- ❌ "spike を作っても捨てるのは無駄、本実装の途中で迷う" (= spike の役割は
  judgement cost を下げること)
- ❌ "失敗 chunk を amend で隠す" (= history が見えなくなり root-cause 困難化)
- ❌ "progress を memory で覚える / handover narrative で書く" (= live yaml の
  方が一次情報)

## Enforcement

- 本 rule auto-load on the listed paths
- `scripts/check_subrow_exit.sh` (§9.12-A; chunk close 時に exit 条件 literal
  確認)
- `.dev/p9_completion_progress.yaml` (§9.12-A; seed)

## Related

- ADR-0073 (build-option DCE substrate; §9.12-B 完成 target)
- マスター計画書 §8 (インクリメンタル工程 + spike 運用)
- `.claude/rules/spike_lifecycle.md`
- `.claude/rules/extended_challenge.md` Step 4
- `.claude/rules/no_handover_predictions.md`
