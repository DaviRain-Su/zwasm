---
name: dispatch_consistency_audit
description: Audit Q3 C 採択の dispatch substrate 整合性 — ZirOp tag count = per-op file count = 5 軸 handler 実装 count の三位一致; `wasm_level` / `wasi_level` metadata 整合; build-option DCE が期待通り効くかサンプリング確認. §9.12-B 完成後 + 定期 audit_scaffolding boundary 時に fire.
---

# dispatch_consistency_audit

> **状態**: skeleton (2026-05-19)。ADR-0071 §Q3 + ADR-0073 で justify。
> §9.12-A で initial wire-up、§9.12-B 完成後に full 機能化。

## 目的

Q3 C 採択 (per-op file + comptime collector + build-option DCE) の **整合性**
を自動 audit する。マスター計画書 §7.7 (Q3 C 設計整合性 audit) の skeleton。

dispatch substrate は以下の 3 軸で整合していなければならない:

1. **ZirOp tag count = per-op file count** — `src/ir/zir.zig` の ZirOp enum
   tag 数と、`src/instruction/wasm_X_Y/**/*.zig` の per-op file 数が一致する
   (placeholder ファイルは除く)
2. **5 軸 handler 完全性** — 各 op file が `pub const handlers = .{ .validate,
   .lower, .arm64, .x86_64, .interp }` の 5 軸全部を持つ
3. **feature_level metadata 整合** — 各 op の `wasm_level` が spec 定義と一致
   (Wasm 1.0 op は `.v1_0`、Wasm 2.0 SIMD op は `.v2_0` etc.)

加えて:

4. **build-option DCE 確認** — `-Dwasm=v1_0` build に Wasm 2.0+ シンボルが
   含まれない (= `scripts/check_build_dce.sh` のサンプリング)

## When to invoke

- §9.12-B (Q3 C 採択完成) 直後
- 各 §9.12-* chunk close 時の sanity check
- `audit_scaffolding` boundary mandatory invocation に統合 (§H 拡張)
- Phase boundary (= ROADMAP §9.13 [x] flip 直前)

ユーザーが手動で `/dispatch_consistency_audit` 起動も可。

## Procedure

> §9.12-B 完成後に実装。skeleton stage の現在は概要のみ。

1. ZirOp tag enumeration 取得 (`zig build` + comptime export 経由)
2. `src/instruction/wasm_X_Y/**/*.zig` の populated file (≥ 30 LOC 等 heuristic)
   をリストアップ
3. Set diff: tag set vs file set; missing report
4. 各 file の `pub const handlers` field 確認 (5 軸; 欠落 report)
5. 各 file の `wasm_level` 値を spec 対応表 (`.dev/wasm_3_0_zirop_mapping.md`
   等) と照合 (drift report)
6. `bash scripts/check_build_dce.sh --sample 5` 実行; PASS 確認
7. 上記 4 check の結果を `private/dispatch_audit-YYYY-MM-DD.md` に出力

## Severity

- ZirOp tag に対応 file 無し → `block`
- 5 軸の handler 欠落 → `block`
- feature_level metadata と spec 不一致 → `block`
- build-option DCE サンプリング fail → `block`

すべて `block`。Q3 C 採用は dispatch consistency が前提だから。

## Related

- ADR-0071 §Q3 (Phase 9 完備 substrate audit resolution)
- ADR-0073 (build-option DCE substrate)
- マスター計画書 §7.7
- `scripts/check_build_dce.sh` (§9.12-A で skeleton)
- `audit_scaffolding §H` (§9.12-A で新規)
