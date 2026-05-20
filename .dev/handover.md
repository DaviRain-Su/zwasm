# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_structural_debt_close_plan.md`](phase9_structural_debt_close_plan.md)
   (Status: Proposed 2026-05-20). この close-plan が
   `/continue` Step 1a の override を発火させ、ROADMAP
   §9.<N> task より先に §6 Work sequence を実行する。
   **D-153 / B159 以降の cross-module imports work には
   触らない** (close-plan §6 (j) まで凍結)。
2. **READ NEXT** [`.dev/lessons/2026-05-20-refactor-tradeoffs-honest-accounting.md`](lessons/2026-05-20-refactor-tradeoffs-honest-accounting.md) — 経緯記録。
3. `git log --oneline -10` — last code commit: `9beb73ca`
   (B158, validator_globals imports prefix). 以降は docs-
   only。
4. `bash scripts/p9_completion_status.sh` — live progress
   (cross-module imports 100 sites 不動)。
5. `.dev/debt.md::D-154` — close-plan umbrella row。

## Active state

- Phase 9.12-E。close-plan §6 完了 (a)〜(i) + (j) impl 開始。
- ADR-0080 は user-collab spike 結果を経て **Rejected**
  (commit `dc07b79`)。spectest を `.wat` で auto-register
  する v1/wazero 方式を採用 → §6 (j) を spike-first から
  direct implementation に変更。
- §6 (j) Step A 完了 (commit `f5b3f62`): `test/spec/spectest.wat`
  + build.zig wat2wasm step + @embedFile route。
  Mac 計測: runtime-skip 192 → 80 (-112)、新規 43 failures
  surface (= B146-B158 残バグ cohort)。
- 次: **§6 (j) Step B** — 43 failures を root-cause cohort
  単位で discharge。優先順:
  1. 21 × UnsupportedEntrySignature (init-time) — 最大
     cohort。entry helper signature dispatch gap の可能性。
     どの export を呼んで起きるか trace 必要。
  2. 7 × globals-zero (`got 0, expected 666`) — per-exporter
     scratch_globals wiring が import 側 zero buffer を読む
     bug。`rt.globals_base` の cross-module 切り替え不全。
  3. 5 × InvalidFuncIndex / 2 × InvalidFunctype — funcref
     resolution gap (elem/imports cohort)。
  4. 4 × assert_uninstantiable but instantiated cleanly —
     unlinkable/uninstantiable 区別の緩さ。

## Open questions / blockers

- なし。autonomous loop resumed。

## §9.12-B progress chunks

`.dev/phase_log/p9_12_B_chunks.md` (B1〜B158 = 138 chunks)
に移管。handover はポインタのみ保持。chunk table 蓄積に
よる handover 肥大 (A1 / C5) を解消。

## See

- [ROADMAP](./ROADMAP.md) §9.12 — phase row
- [`debt.md`](./debt.md) — D-154 umbrella, D-153 paused
- [`lessons/INDEX.md`](./lessons/INDEX.md) — 2026-05-20 entry
