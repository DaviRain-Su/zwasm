---
description: "Spike lifecycle discipline — private/spikes/<slug>/ の Status 管理 + rejected/archived 時の lesson 必須 + running >14d で audit flag。`extended_challenge.md` Step 4 から抽出+強化。"
paths:
  - "private/spikes/**/README.md"
  - ".dev/lessons/**"
---

# Spike lifecycle

> **状態**: skeleton (2026-05-19)。§9.12-A enforcement layer で完成。

## The rule

`private/spikes/<slug>/` directory は **lifecycle Status を必ず持つ**:

| Status | 意味 |
|---|---|
| `running` | 進行中。最大 14 日 (audit flag) |
| `merged-into-prod` | 本実装に取り込み済。production commit SHA 必須 |
| `rejected` | 不採用。`.dev/lessons/YYYY-MM-DD-<slug>-rejected.md` で結論記録必須 |
| `archived` | 過去 reject; spike dir は残るが活動なし |

各 spike の README.md frontmatter or 先頭で Status 明示:

```markdown
# spike: q3-zig-inline-switch

**Status**: running
**Started**: 2026-05-19
**Outcome**: <TBD>
**Hypothesis**: 581-tag `inline switch` で Zig 0.16 compile-time が wall に当たるか
```

## Why

D-134 (Rosetta heisenbug) の investigation で 5 cycles の hypothesis rejection
が記録されていなかったら、cycle 6 で root-cause 識別ができなかった。spike を
記録なしで捨てると、同じ trial を future-you / next session が再度払う。

「労力厭わず」の規律は「実験を試みる」ことではなく「実験結果を記録する」こと。

## Enforcement

- `scripts/audit_spikes.sh` (既存; §9.12-A で lifecycle check 強化)
- `audit_scaffolding §G.4` (既存; reject lesson land 確認)
- running > 14d で audit が `soon` finding
- rejected w/o lesson で audit が `block` finding

## Migration to lesson on reject

```
1. spike dir に `Status: rejected` + Outcome 記載
2. `.dev/lessons/YYYY-MM-DD-<spike-slug>-rejected.md` を land
   - 鎮重: 何を試したか / なぜ rejected か / 何が学べたか
3. spike dir を `private/spikes/archive/<slug>/` に move (option)
4. commit message で reject 明記
```

## Related

- ADR-0071 §Q3 (3 spikes 採用: q3-zig-inline-switch / q3-interp-dispatch-bench /
  q3-build-option-dce-poc)
- マスター計画書 §7.5
- `.claude/rules/extended_challenge.md` Step 4 (spike 主導の代替探索)
- `.claude/rules/lessons_vs_adr.md`
