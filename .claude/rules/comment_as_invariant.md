---
description: "Prose-only invariant comments (= `Y は X scratch / Y は alignment N / Y は private` 等) を禁止。必ず comptime/runtime assert または lint で強制する。D-132/D-133 failure mode 予防。"
paths:
  - "src/**/*.zig"
---

# Comment-as-invariant rule

> **状態**: skeleton (2026-05-19)。ADR-0072 (Proposed) で justify。§9.12-C で完成。

## The rule

ソース comment で **不変条件 (invariant)** を述べるときは、必ず以下のいずれかと組:

(a) `comptime assert` (`std.debug.assert` を `comptime` 文脈で)
(b) runtime `std.debug.assert`
(c) lint script (`audit_scaffolding §G grep` 経由)
(d) 削除 (= 不要なら書かない)

違反例 (D-132 / D-133 failure mode の元):

```zig
// X10 / X11 / X12 は handler 内の private scratch (= 違反 — prose only)
const tmp_a = encXR(10);
const tmp_b = encXR(11);
```

修正例:

```zig
// abi.zig:
pub const table_emit_scratch_gprs = [_]u4{ 10, 11, 12 };
comptime {
    for (table_emit_scratch_gprs) |r| {
        std.debug.assert(!abi.allocatable_caller_saved_scratch_gprs[r]);
    }
}

// op_table.zig:
const tmp_a = encXR(abi.table_emit_scratch_gprs[0]);
const tmp_b = encXR(abi.table_emit_scratch_gprs[1]);
```

## Why

`op_table.zig` のコメント "X10/X11/X12 are private scratch within the handler"
は prose-only invariant でコード強制無し。regalloc が同 slot を allocatable
scratch として使い、特定 corpus + nested-table-op で silent corruption (D-132)。

Lesson: `.dev/lessons/2026-05-16-regalloc-pool-scratch-overlap.md`

「コメントは documentation; 不変条件は code で強制」が substrate hygiene の柱。

## Enforcement

- 本 rule auto-load on `src/**/*.zig` (claude が編集時に awareness 持つ)
- `audit_scaffolding §G` grep 強化 (§9.12-C; encStrXRegLsl3 等 + register
  numeral hardcode 検出)
- D-133 sweep (§9.12-C): 残存 site を named-constant 経由に置換

## Detection patterns (audit grep の対象)

- `// X[0-9]+ は|are` プロセ comment
- `// .*scratch.*private` プロセ comment
- `encStrXRegLsl3\([0-9]+,` / `encLdrImm\([0-9]+,` (hardcoded register numeral)

## Related

- ADR-0072 (本 rule の根拠)
- ADR-0018 (regalloc reserved set; comptime check の先例)
- ADR-0071 §Q5 (Phase 9 完備 hygiene resolution)
- D-132 / D-133 (failure mode + discharge plan)
- `.dev/lessons/2026-05-16-regalloc-pool-scratch-overlap.md`
