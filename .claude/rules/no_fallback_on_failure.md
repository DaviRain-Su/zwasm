---
description: "Anti-fallback / anti-silent-degradation discipline for Phase 9 完備 substrate. Errors must propagate as named errors or be handled by exhaustive switch with ADR-justified rationale; silent skip / default-on-failure / try-simpler-path patterns are forbidden."
paths:
  - "src/**/*.zig"
  - "test/spec/spec_assert_runner_base.zig"
  - "test/spec/spec_assert_runner_non_simd.zig"
---

# Anti-fallback / anti-silent-degradation

> **状態**: skeleton (2026-05-19)。§9.12-A enforcement layer 構築フェーズで完成。
> 本ファイルは §18.2 ADR 先行要件に対し、ADR-0071 + ADR-0073 + ADR-0050 amend
> の文脈で「あきらめないための機械的 enforcement layer」(マスター計画書 §7 / §7.4)
> の skeleton として land。

## The rule

エラー処理で **silent degradation** に該当する pattern を禁止する。
具体的に:

- ❌ `catch \|err\| return null` (caller に false 情報を返す)
- ❌ `catch \|err\| .default_value` (本来の semantics を勝手に降格)
- ❌ `catch \|err\| switch (err) { else => continue }` (= "知らない error は無視")
- ❌ `catch {}` (= 完全沈黙)
- ❌ runtime に `SKIP-*` token を出力する code を新規追加 (= 諦め path の上書き)

代替:

- ✅ Error 型を named error union として propagate (`!void` / `!T`)
- ✅ Exhaustive switch (`switch (err) { error.X => ..., error.Y => ... }`) — ただし
  ADR で正当化されている場合のみ
- ✅ Trap-class error は spec 上 trap として観測されるべきなので `Error.Trap` 等
  で propagate
- ✅ "知らない error は再度 throw" (`switch (err) { else => |e| return e }`)

## Why

D-026 / D-082 系の bug (silent skip で被害を後で発見) が Phase 9 完備までに
何度も surface した。Phase 9 完備の主軸 exit criterion は "skip-impl == 0"
(§9.12-E) であり、silent fallback が 1 か所でも入れば exit が崩れる。

## Enforcement

- `scripts/check_fallback_patterns.sh` (§9.12-A で実装): grep ベース detection
- `audit_scaffolding §G.6` (§9.12-A で land)
- ADR-0050 D-3 (skip-impl one-way ratchet): runtime SKIP-* 増加 = ADR 必須

## 例外

ADR で正当化されている fallback は許容。例:
- ADR-0029 (skip-impl vs skip-adr semantics) で正当化される skip-adr-* prefix
  (= 仕様上 v2 範囲外の意図的スキップ)

## Stale-ness

`scripts/check_fallback_patterns.sh` の grep pattern を grep 検出する関数群の
シグネチャ変更で false-positive 化する可能性。`audit_scaffolding §G.6` で生存
確認。

## Related

- ADR-0050 amend (D-3 / D-4 skip-impl one-way ratchet)
- ADR-0071 §Q3 (Phase 9 完備 substrate audit resolution)
- マスター計画書 §7.4
- `.claude/rules/no_workaround.md` (sibling rule; SKIP-* 増加禁止文言)
- `.claude/rules/extended_challenge.md` Step 4 (spike 主導の代替探索)
